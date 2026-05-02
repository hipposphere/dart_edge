import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:data_assets/data_assets.dart';

import 'sql_file_migration_source.dart';
import 'sql_migration.dart';
import 'sql_migration_file_sorting.dart';
import 'sql_migration_plan.dart';

/// Serializable manifest for SQL migrations bundled as one Dart data asset.
final class SqlMigrationManifest {
  const SqlMigrationManifest({
    required this.package,
    required this.entries,
    this.version = 1,
  });

  /// Builds a manifest from one migration folder.
  static Future<SqlMigrationManifest> fromFolder({
    required String package,
    required String folder,
    String assetNamePrefix = 'migrations',
    SqlMigrationFileSorting sorting =
        const SqlMigrationFileSorting.lexicographic(),
  }) async {
    final directory = Directory(folder);
    if (!await directory.exists()) {
      throw ArgumentError.value(
        folder,
        'folder',
        'Migration folder does not exist.',
      );
    }

    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.uri.pathSegments.last.endsWith('.sql')) {
        files.add(entity);
      }
    }

    files.sort((left, right) {
      return sorting.compare(_stem(left), _stem(right));
    });

    final normalizedPrefix = assetNamePrefix.stripTrailingSlash;
    return SqlMigrationManifest(
      package: package,
      entries: List.unmodifiable([
        for (final file in files)
          SqlMigrationManifestEntry(
            name: '$normalizedPrefix/${file.uri.pathSegments.last}',
            sql: await file.readAsString(),
            file: file.uri,
          ),
      ]),
    );
  }

  /// Decodes a manifest from JSON text.
  factory SqlMigrationManifest.fromJsonString(String source) {
    return SqlMigrationManifest.fromJson(
      jsonDecode(source) as Map<String, Object?>,
    );
  }

  /// Decodes a manifest from a JSON object.
  factory SqlMigrationManifest.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version is! int || version != 1) {
      throw FormatException('Unsupported SQL migration manifest version.');
    }

    final package = json['package'];
    if (package is! String || package.isEmpty) {
      throw FormatException('SQL migration manifest package is required.');
    }

    final entries = json['entries'];
    if (entries is! List) {
      throw FormatException('SQL migration manifest entries are required.');
    }

    return SqlMigrationManifest(
      version: version,
      package: package,
      entries: List.unmodifiable([
        for (final entry in entries)
          SqlMigrationManifestEntry.fromJson(entry as Map<String, Object?>),
      ]),
    );
  }

  /// Manifest format version.
  final int version;

  /// Dart package that owns the manifest data asset.
  final String package;

  /// SQL file entries embedded in deterministic order.
  final List<SqlMigrationManifestEntry> entries;

  /// Converts this manifest to ordered migrations.
  List<SqlMigration> toMigrations({
    SqlMigrationFileSorting sorting =
        const SqlMigrationFileSorting.lexicographic(),
  }) {
    final groupedArtifacts = <String, _SqlMigrationManifestGroup>{};

    for (final entry in entries) {
      final artifact = _parseArtifact(entry);
      if (artifact == null) {
        continue;
      }

      groupedArtifacts
          .putIfAbsent(
            artifact.stem,
            () => _SqlMigrationManifestGroup(stem: artifact.stem),
          )
          .add(artifact);
    }

    final stems = groupedArtifacts.keys.toList(growable: false)
      ..sort(sorting.compare);

    return List<SqlMigration>.unmodifiable([
      for (final stem in stems)
        groupedArtifacts[stem]!.toMigration(sorting: sorting),
    ]);
  }

  /// Converts this manifest to a JSON object.
  Map<String, Object?> toJson() {
    return {
      'version': version,
      'package': package,
      'entries': [for (final entry in entries) entry.toJson()],
    };
  }

  /// Encodes this manifest as JSON text.
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Writes this manifest to [file].
  Future<void> writeJsonFile(Uri file) async {
    await File.fromUri(file).writeAsString(toJsonString());
  }

  /// Writes this manifest to [file] and returns the manifest data asset.
  Future<DataAsset> writeDataAsset({
    required String name,
    required Uri file,
  }) async {
    await writeJsonFile(file);
    return toDataAsset(name: name, file: file);
  }

  /// Source files used by this manifest, for build hook dependency tracking.
  Iterable<Uri> get sourceFiles sync* {
    for (final entry in entries) {
      if (entry.file case final file?) {
        yield file;
      }
    }
  }

  /// Data asset for the manifest JSON file.
  DataAsset toDataAsset({required String name, required Uri file}) {
    return DataAsset(package: package, name: name, file: file);
  }
}

/// One embedded SQL file entry in a [SqlMigrationManifest].
final class SqlMigrationManifestEntry {
  const SqlMigrationManifestEntry({
    required this.name,
    required this.sql,
    this.file,
  });

  factory SqlMigrationManifestEntry.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) {
      throw FormatException('SQL migration manifest entry name is required.');
    }

    final sql = json['sql'];
    if (sql is! String) {
      throw FormatException('SQL migration manifest entry SQL is required.');
    }

    return SqlMigrationManifestEntry(name: name, sql: sql);
  }

  /// Logical source name, usually the original SQL file path inside the package.
  final String name;

  /// SQL source embedded in the manifest.
  final String sql;

  /// Source file for build hook dependency tracking.
  final Uri? file;

  /// Converts this entry to a JSON object.
  Map<String, Object?> toJson() {
    return {'name': name, 'sql': sql};
  }
}

enum _SqlMigrationDirection { up, down }

final class _SqlMigrationManifestArtifact {
  const _SqlMigrationManifestArtifact({
    required this.stem,
    required this.entry,
    required this.direction,
    required this.dialect,
  });

  final String stem;
  final SqlMigrationManifestEntry entry;
  final _SqlMigrationDirection direction;
  final SqlDialect? dialect;
}

final class _SqlMigrationManifestGroup {
  _SqlMigrationManifestGroup({required this.stem});

  final String stem;
  SqlMigrationManifestEntry? sharedUp;
  SqlMigrationManifestEntry? sharedDown;
  final Map<SqlDialect, SqlMigrationManifestEntry> upByDialect =
      <SqlDialect, SqlMigrationManifestEntry>{};
  final Map<SqlDialect, SqlMigrationManifestEntry> downByDialect =
      <SqlDialect, SqlMigrationManifestEntry>{};

  void add(_SqlMigrationManifestArtifact artifact) {
    switch ((artifact.direction, artifact.dialect)) {
      case (_SqlMigrationDirection.up, null):
        _setSingle(
          current: sharedUp,
          next: artifact.entry,
          description: 'shared up',
        );
        sharedUp = artifact.entry;
      case (_SqlMigrationDirection.down, null):
        _setSingle(
          current: sharedDown,
          next: artifact.entry,
          description: 'shared down',
        );
        sharedDown = artifact.entry;
      case (_SqlMigrationDirection.up, final dialect?):
        _setSingle(
          current: upByDialect[dialect],
          next: artifact.entry,
          description: '${dialect.name} up',
        );
        upByDialect[dialect] = artifact.entry;
      case (_SqlMigrationDirection.down, final dialect?):
        _setSingle(
          current: downByDialect[dialect],
          next: artifact.entry,
          description: '${dialect.name} down',
        );
        downByDialect[dialect] = artifact.entry;
    }
  }

  SqlMigration toMigration({required SqlMigrationFileSorting sorting}) {
    if (sharedUp == null && upByDialect.isEmpty) {
      throw StateError('Migration "$stem" has no up SQL entry.');
    }

    final identity = sorting.parse(stem);
    return SqlMigration(
      version: identity.version,
      name: identity.name,
      up: SqlMigrationPlan(
        shared: _readStatements(sharedUp),
        byDialect: _readDialectStatements(upByDialect),
      ),
      down: SqlMigrationPlan(
        shared: _readStatements(sharedDown),
        byDialect: _readDialectStatements(downByDialect),
      ),
    );
  }

  void _setSingle({
    required SqlMigrationManifestEntry? current,
    required SqlMigrationManifestEntry next,
    required String description,
  }) {
    if (current != null) {
      throw StateError(
        'Found multiple $description migration entries for "$stem": '
        '${current.name} and ${next.name}.',
      );
    }
  }
}

_SqlMigrationManifestArtifact? _parseArtifact(SqlMigrationManifestEntry entry) {
  final name = entry.name.split('/').last;
  if (!name.endsWith('.sql')) {
    return null;
  }

  var stem = name.substring(0, name.length - '.sql'.length);
  var direction = _SqlMigrationDirection.up;
  SqlDialect? dialect;

  if (stem.endsWith('.down.sqlite')) {
    stem = stem.substring(0, stem.length - '.down.sqlite'.length);
    direction = _SqlMigrationDirection.down;
    dialect = SqlDialect.sqlite;
  } else if (stem.endsWith('.down.postgres')) {
    stem = stem.substring(0, stem.length - '.down.postgres'.length);
    direction = _SqlMigrationDirection.down;
    dialect = SqlDialect.postgres;
  } else if (stem.endsWith('.down')) {
    stem = stem.substring(0, stem.length - '.down'.length);
    direction = _SqlMigrationDirection.down;
  } else if (stem.endsWith('.sqlite')) {
    stem = stem.substring(0, stem.length - '.sqlite'.length);
    dialect = SqlDialect.sqlite;
  } else if (stem.endsWith('.postgres')) {
    stem = stem.substring(0, stem.length - '.postgres'.length);
    dialect = SqlDialect.postgres;
  }

  if (stem.isEmpty) {
    throw FormatException(
      'Invalid migration manifest entry name "${entry.name}".',
    );
  }

  return _SqlMigrationManifestArtifact(
    stem: stem,
    entry: entry,
    direction: direction,
    dialect: dialect,
  );
}

Map<SqlDialect, List<SqlStatement>> _readDialectStatements(
  Map<SqlDialect, SqlMigrationManifestEntry> entries,
) {
  final result = <SqlDialect, List<SqlStatement>>{};
  for (final entry in entries.entries) {
    result[entry.key] = _readStatements(entry.value);
  }
  return result;
}

List<SqlStatement> _readStatements(SqlMigrationManifestEntry? entry) {
  if (entry == null) {
    return const <SqlStatement>[];
  }

  return List<SqlStatement>.unmodifiable(
    splitSqlMigrationStatements(entry.sql),
  );
}

extension on String {
  String get stripTrailingSlash {
    var result = this;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

String _stem(File file) {
  final name = file.uri.pathSegments.last;
  return name.substring(0, name.length - '.sql'.length);
}
