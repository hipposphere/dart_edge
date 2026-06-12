import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'sql_schema_migration.dart';

/// Writes schema diffs as SQL migration files.
final class SqlSchemaMigrationFileWriter {
  const SqlSchemaMigrationFileWriter({
    required this.folder,
    this.dialects = SqlDialect.values,
  });

  /// Folder where migration SQL files should be created.
  final String folder;

  /// Dialects that should receive generated SQL.
  final List<SqlDialect> dialects;

  /// Writes a migration file set for [diff].
  ///
  /// When every dialect renders identical SQL, one shared `<stem>.sql` file is
  /// written. Otherwise, dialect-specific `<stem>.sqlite.sql` and
  /// `<stem>.postgres.sql` files are written.
  Future<SqlSchemaMigrationFileSet> writeFlywayMigration({
    required String version,
    required String name,
    required SqlSchemaDiff diff,
    bool includeReviewedOperations = false,
    bool includeDestructiveOperations = false,
  }) async {
    final stem = 'V${_validateVersion(version)}__${_slugName(name)}';
    return writeMigration(
      stem: stem,
      diff: diff,
      includeReviewedOperations: includeReviewedOperations,
      includeDestructiveOperations: includeDestructiveOperations,
    );
  }

  /// Writes a migration file set for [diff] using an already-formed file stem.
  Future<SqlSchemaMigrationFileSet> writeMigration({
    required String stem,
    required SqlSchemaDiff diff,
    bool includeReviewedOperations = false,
    bool includeDestructiveOperations = false,
  }) async {
    if (stem.isEmpty || stem.contains('/') || stem.contains(r'\')) {
      throw ArgumentError.value(
        stem,
        'stem',
        'Migration stem must be a file name without path separators.',
      );
    }

    final directory = Directory(folder);
    await directory.create(recursive: true);

    final plan = diff.toMigrationPlan(
      includeReviewedOperations: includeReviewedOperations,
      includeDestructiveOperations: includeDestructiveOperations,
    );
    final renderedByDialect = <SqlDialect, String>{
      for (final dialect in dialects)
        dialect: _renderStatements(plan.forDialect(dialect)),
    };
    final nonEmptySql = renderedByDialect.values.where((sql) => sql.isNotEmpty);
    if (nonEmptySql.isEmpty) {
      throw StateError('Schema diff did not render any migration SQL.');
    }

    final writtenFiles = <File>[];
    final uniqueSql = renderedByDialect.values.toSet();
    if (uniqueSql.length == 1) {
      writtenFiles.add(
        await _writeNewFile(directory, '$stem.sql', uniqueSql.single),
      );
    } else {
      for (final entry in renderedByDialect.entries) {
        if (entry.value.isEmpty) {
          continue;
        }
        writtenFiles.add(
          await _writeNewFile(
            directory,
            '$stem.${entry.key.name}.sql',
            entry.value,
          ),
        );
      }
    }

    return SqlSchemaMigrationFileSet(
      stem: stem,
      files: List.unmodifiable(writtenFiles),
    );
  }

  Future<File> _writeNewFile(
    Directory directory,
    String fileName,
    String contents,
  ) async {
    final file = File.fromUri(directory.uri.resolve(fileName));
    if (await file.exists()) {
      throw StateError('Migration file already exists: ${file.path}');
    }
    return file.writeAsString(contents);
  }
}

/// Files written for one generated schema migration.
final class SqlSchemaMigrationFileSet {
  const SqlSchemaMigrationFileSet({required this.stem, required this.files});

  /// Logical migration stem, without `.sql` or dialect suffixes.
  final String stem;

  /// Files created for the migration.
  final List<File> files;
}

String _renderStatements(List<SqlStatement> statements) {
  return statements
      .map((statement) => statement.sql.trim())
      .where((statement) => statement.isNotEmpty)
      .map((statement) => statement.endsWith(';') ? statement : '$statement;')
      .join('\n\n');
}

String _validateVersion(String version) {
  if (!RegExp(r'^[0-9]+(?:[._][0-9]+)*$').hasMatch(version)) {
    throw ArgumentError.value(
      version,
      'version',
      'Flyway versions must contain numeric segments separated by "." or "_".',
    );
  }
  return version;
}

String _slugName(String name) {
  final slug = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.isEmpty) {
    throw ArgumentError.value(
      name,
      'name',
      'Migration name must not be empty.',
    );
  }
  return slug;
}
