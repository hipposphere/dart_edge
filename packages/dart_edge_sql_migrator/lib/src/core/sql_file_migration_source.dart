import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'sql_migration.dart';
import 'sql_migration_file_sorting.dart';
import 'sql_migration_plan.dart';

/// Loads SQL migrations from one folder on disk.
final class SqlFileMigrationSource {
  const SqlFileMigrationSource({
    required this.folder,
    this.sorting = const SqlMigrationFileSorting.lexicographic(),
  });

  /// Folder that contains the migration SQL files.
  final String folder;

  /// Strategy used to sort and parse file names.
  final SqlMigrationFileSorting sorting;

  /// Reads the folder and returns ordered migrations.
  Future<List<SqlMigration>> load() async {
    final directory = Directory(folder);
    if (!await directory.exists()) {
      throw ArgumentError.value(
        folder,
        'folder',
        'Migration folder does not exist.',
      );
    }

    final groupedArtifacts = <String, _SqlMigrationArtifactGroup>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final artifact = _parseArtifact(entity);
      if (artifact == null) {
        continue;
      }

      groupedArtifacts
          .putIfAbsent(
            artifact.stem,
            () => _SqlMigrationArtifactGroup(stem: artifact.stem),
          )
          .add(artifact);
    }

    final stems = groupedArtifacts.keys.toList(growable: false)
      ..sort(sorting.compare);

    return List<SqlMigration>.unmodifiable([
      for (final stem in stems)
        await groupedArtifacts[stem]!.toMigration(sorting: sorting),
    ]);
  }
}

enum _SqlMigrationDirection { up, down }

final class _SqlMigrationArtifact {
  const _SqlMigrationArtifact({
    required this.stem,
    required this.file,
    required this.direction,
    required this.dialect,
  });

  final String stem;
  final File file;
  final _SqlMigrationDirection direction;
  final SqlDialect? dialect;
}

final class _SqlMigrationArtifactGroup {
  _SqlMigrationArtifactGroup({required this.stem});

  final String stem;
  File? sharedUp;
  File? sharedDown;
  final Map<SqlDialect, File> upByDialect = <SqlDialect, File>{};
  final Map<SqlDialect, File> downByDialect = <SqlDialect, File>{};

  void add(_SqlMigrationArtifact artifact) {
    switch ((artifact.direction, artifact.dialect)) {
      case (_SqlMigrationDirection.up, null):
        _setSingle(
          current: sharedUp,
          next: artifact.file,
          description: 'shared up',
        );
        sharedUp = artifact.file;
      case (_SqlMigrationDirection.down, null):
        _setSingle(
          current: sharedDown,
          next: artifact.file,
          description: 'shared down',
        );
        sharedDown = artifact.file;
      case (_SqlMigrationDirection.up, final dialect?):
        _setMapSingle(
          current: upByDialect[dialect],
          next: artifact.file,
          description: '${dialect.name} up',
        );
        upByDialect[dialect] = artifact.file;
      case (_SqlMigrationDirection.down, final dialect?):
        _setMapSingle(
          current: downByDialect[dialect],
          next: artifact.file,
          description: '${dialect.name} down',
        );
        downByDialect[dialect] = artifact.file;
    }
  }

  Future<SqlMigration> toMigration({
    required SqlMigrationFileSorting sorting,
  }) async {
    if (sharedUp == null && upByDialect.isEmpty) {
      throw StateError('Migration "$stem" has no up SQL file.');
    }

    final identity = sorting.parse(stem);
    return SqlMigration(
      version: identity.version,
      name: identity.name,
      up: SqlMigrationPlan(
        shared: await _readStatements(sharedUp),
        byDialect: await _readDialectStatements(upByDialect),
      ),
      down: SqlMigrationPlan(
        shared: await _readStatements(sharedDown),
        byDialect: await _readDialectStatements(downByDialect),
      ),
    );
  }

  void _setSingle({
    required File? current,
    required File next,
    required String description,
  }) {
    if (current != null) {
      throw StateError(
        'Found multiple $description migration files for "$stem": '
        '${current.path} and ${next.path}.',
      );
    }
  }

  void _setMapSingle({
    required File? current,
    required File next,
    required String description,
  }) {
    if (current != null) {
      throw StateError(
        'Found multiple $description migration files for "$stem": '
        '${current.path} and ${next.path}.',
      );
    }
  }
}

_SqlMigrationArtifact? _parseArtifact(File file) {
  final name = file.uri.pathSegments.isEmpty
      ? file.path
      : file.uri.pathSegments.last;
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
    throw FormatException('Invalid migration file name "${file.path}".');
  }

  return _SqlMigrationArtifact(
    stem: stem,
    file: file,
    direction: direction,
    dialect: dialect,
  );
}

Future<Map<SqlDialect, List<SqlStatement>>> _readDialectStatements(
  Map<SqlDialect, File> files,
) async {
  final result = <SqlDialect, List<SqlStatement>>{};
  for (final entry in files.entries) {
    result[entry.key] = await _readStatements(entry.value);
  }
  return result;
}

Future<List<SqlStatement>> _readStatements(File? file) async {
  if (file == null) {
    return const <SqlStatement>[];
  }

  final source = await file.readAsString();
  return List<SqlStatement>.unmodifiable(_splitSqlStatements(source));
}

List<SqlStatement> _splitSqlStatements(String source) {
  final statements = <SqlStatement>[];
  final buffer = StringBuffer();

  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;

  for (var index = 0; index < source.length; index += 1) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (inLineComment) {
      buffer.write(char);
      if (char == '\n') {
        inLineComment = false;
      }
      continue;
    }

    if (inBlockComment) {
      buffer.write(char);
      if (char == '*' && next == '/') {
        buffer.write(next);
        index += 1;
        inBlockComment = false;
      }
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote) {
      if (char == '-' && next == '-') {
        buffer
          ..write(char)
          ..write(next);
        index += 1;
        inLineComment = true;
        continue;
      }

      if (char == '/' && next == '*') {
        buffer
          ..write(char)
          ..write(next);
        index += 1;
        inBlockComment = true;
        continue;
      }
    }

    if (char == "'" && !inDoubleQuote) {
      if (inSingleQuote && next == "'") {
        buffer
          ..write(char)
          ..write(next);
        index += 1;
        continue;
      }
      inSingleQuote = !inSingleQuote;
      buffer.write(char);
      continue;
    }

    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }

    if (char == ';' && !inSingleQuote && !inDoubleQuote) {
      final statement = buffer.toString().trim();
      if (statement.isNotEmpty) {
        statements.add(sql(statement));
      }
      buffer.clear();
      continue;
    }

    buffer.write(char);
  }

  final trailing = buffer.toString().trim();
  if (trailing.isNotEmpty) {
    statements.add(sql(trailing));
  }

  return statements;
}
