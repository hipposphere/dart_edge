import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'applied_sql_migration.dart';
import 'sql_file_migration_source.dart';
import 'sql_migration.dart';
import 'sql_migration_file_sorting.dart';
import 'sql_migration_manifest.dart';
import 'sql_migration_status.dart';

/// Migration manager for SQLite and PostgreSQL databases.
final class DartEdgeSqlMigrator {
  DartEdgeSqlMigrator({
    required this.pool,
    required Iterable<SqlMigration> migrations,
    this.tableSchema = defaultPostgresTableSchema,
    this.tableName = defaultTableName,
  }) : migrations = List<SqlMigration>.unmodifiable(migrations) {
    _validateSqlIdentifier(tableSchema, 'tableSchema');
    _validateTableName(tableName);
    _validateMigrations(this.migrations);
  }

  /// Default PostgreSQL schema used for the metadata table.
  static const defaultPostgresTableSchema = 'dart_edge_internal';

  static const defaultTableName = 'migrations';

  /// Database pool used to apply migrations.
  final SqlPool pool;

  /// Ordered migrations known to this manager.
  final List<SqlMigration> migrations;

  /// Metadata table used to record applied migrations.
  final String tableName;

  /// PostgreSQL schema used for the metadata table.
  ///
  /// SQLite does not support schemas, so this value is ignored for SQLite.
  final String tableSchema;

  /// Creates a migrator by loading migrations from [folder].
  static Future<DartEdgeSqlMigrator> fromFolder({
    required SqlPool pool,
    required String folder,
    SqlMigrationFileSorting sorting =
        const SqlMigrationFileSorting.lexicographic(),
    String tableSchema = defaultPostgresTableSchema,
    String tableName = defaultTableName,
  }) async {
    final migrations = await SqlFileMigrationSource(
      folder: folder,
      sorting: sorting,
    ).load();
    return DartEdgeSqlMigrator(
      pool: pool,
      migrations: migrations,
      tableSchema: tableSchema,
      tableName: tableName,
    );
  }

  /// Creates a migrator from an already-loaded migration manifest.
  static Future<DartEdgeSqlMigrator> fromManifest({
    required SqlPool pool,
    required SqlMigrationManifest manifest,
    SqlMigrationFileSorting sorting =
        const SqlMigrationFileSorting.lexicographic(),
    String tableSchema = defaultPostgresTableSchema,
    String tableName = defaultTableName,
  }) async {
    return DartEdgeSqlMigrator(
      pool: pool,
      migrations: manifest.toMigrations(sorting: sorting),
      tableSchema: tableSchema,
      tableName: tableName,
    );
  }

  /// Creates a migrator by loading one data asset containing the migration manifest.
  static Future<DartEdgeSqlMigrator> fromDataAsset({
    required SqlPool pool,
    required String assetId,
    required Future<String> Function(String assetId) loadString,
    SqlMigrationFileSorting sorting =
        const SqlMigrationFileSorting.lexicographic(),
    String tableSchema = defaultPostgresTableSchema,
    String tableName = defaultTableName,
  }) async {
    final manifest = SqlMigrationManifest.fromJsonString(
      await loadString(assetId),
    );
    return DartEdgeSqlMigrator(
      pool: pool,
      migrations: manifest.toMigrations(sorting: sorting),
      tableSchema: tableSchema,
      tableName: tableName,
    );
  }

  /// Returns the current migration status for the database.
  Future<SqlMigrationStatus> status() {
    return pool.withTransaction((transaction) async {
      await _ensureMetadataTable(transaction);
      final applied = await _loadAppliedMigrations(transaction);
      _ensureAppliedPrefix(applied);
      return SqlMigrationStatus(
        available: migrations,
        applied: applied,
        pending: List<SqlMigration>.unmodifiable(
          migrations.skip(applied.length),
        ),
      );
    });
  }

  /// Applies every pending migration.
  Future<int> migrateToLatest() async {
    if (migrations.isEmpty) {
      await pool.withTransaction(_ensureMetadataTable);
      return 0;
    }

    return pool.withTransaction((transaction) async {
      return _migrateToIndex(transaction, migrations.length - 1);
    });
  }

  /// Migrates the database to [version].
  ///
  /// If [version] is ahead of the current database state, pending migrations
  /// are applied. If it is behind, migrations are rolled back using their
  /// `down` plans.
  Future<int> migrateToVersion(String version) {
    final targetIndex = migrations.indexWhere(
      (migration) => migration.version == version,
    );
    if (targetIndex == -1) {
      throw ArgumentError.value(
        version,
        'version',
        'Unknown migration version.',
      );
    }

    return pool.withTransaction((transaction) async {
      return _migrateToIndex(transaction, targetIndex);
    });
  }

  /// Rolls back [steps] applied migrations.
  Future<int> rollback({int steps = 1}) {
    RangeError.checkValueInInterval(steps, 1, 1 << 31, 'steps');

    return pool.withTransaction((transaction) async {
      await _ensureMetadataTable(transaction);
      final applied = await _loadAppliedMigrations(transaction);
      _ensureAppliedPrefix(applied);
      if (applied.isEmpty) {
        return 0;
      }

      final currentIndex = applied.length - 1;
      final targetIndex = currentIndex - steps;
      return _migrateToIndex(transaction, targetIndex < -1 ? -1 : targetIndex);
    });
  }

  Future<int> _migrateToIndex(
    SqlTransaction transaction,
    int targetIndex,
  ) async {
    await _ensureMetadataTable(transaction);
    final applied = await _loadAppliedMigrations(transaction);
    _ensureAppliedPrefix(applied);

    final currentIndex = applied.length - 1;
    if (currentIndex == targetIndex) {
      return 0;
    }

    if (targetIndex > currentIndex) {
      var appliedCount = 0;
      for (var index = currentIndex + 1; index <= targetIndex; index += 1) {
        final migration = migrations[index];
        await _applyMigration(transaction, migration);
        appliedCount += 1;
      }
      return appliedCount;
    }

    var revertedCount = 0;
    for (var index = currentIndex; index > targetIndex; index -= 1) {
      final migration = migrations[index];
      await _revertMigration(transaction, migration);
      revertedCount += 1;
    }
    return revertedCount;
  }

  Future<void> _ensureMetadataTable(SqlExecutor executor) async {
    if (executor.dialect == SqlDialect.postgres) {
      await executor.execute(_createMetadataSchemaStatement());
    }
    await executor.execute(_createMetadataTableStatement(executor.dialect));
  }

  Future<List<AppliedSqlMigration>> _loadAppliedMigrations(
    SqlExecutor executor,
  ) async {
    final result = await executor.execute(_selectAppliedMigrationsStatement());
    return List<AppliedSqlMigration>.unmodifiable([
      for (final row in result.rows)
        AppliedSqlMigration(
          version: row.read<String>('version'),
          name: row.read<String>('name'),
          appliedAt: _readAppliedAt(row.read<Object?>('applied_at')),
        ),
    ]);
  }

  Future<void> _applyMigration(
    SqlTransaction transaction,
    SqlMigration migration,
  ) async {
    final statements = migration.up.forDialect(transaction.dialect);
    if (statements.isEmpty) {
      throw StateError(
        'Migration "${migration.version}" has no up statements for '
        '${transaction.dialect.displayName}.',
      );
    }

    for (final statement in statements) {
      await transaction.execute(statement);
    }

    await transaction.execute(
      _insertAppliedMigrationStatement(transaction.dialect, migration),
    );
  }

  Future<void> _revertMigration(
    SqlTransaction transaction,
    SqlMigration migration,
  ) async {
    if (migration.down.isEmpty) {
      throw StateError(
        'Migration "${migration.version}" cannot be rolled back because no '
        'down plan was provided.',
      );
    }

    final statements = migration.down.forDialect(transaction.dialect);
    if (statements.isEmpty) {
      throw StateError(
        'Migration "${migration.version}" has no down statements for '
        '${transaction.dialect.displayName}.',
      );
    }

    for (final statement in statements) {
      await transaction.execute(statement);
    }

    await transaction.execute(
      _deleteAppliedMigrationStatement(transaction.dialect, migration.version),
    );
  }

  void _ensureAppliedPrefix(List<AppliedSqlMigration> applied) {
    if (applied.length > migrations.length) {
      throw StateError(
        'Database contains more applied migrations than this migrator knows about.',
      );
    }

    for (var index = 0; index < applied.length; index += 1) {
      final expected = migrations[index];
      final actual = applied[index];
      if (expected.version != actual.version) {
        throw StateError(
          'Database migration state does not match the configured order. '
          'Expected "${expected.version}" at position ${index + 1}, '
          'but found "${actual.version}".',
        );
      }
    }
  }

  SqlStatement _createMetadataSchemaStatement() {
    return sql('CREATE SCHEMA IF NOT EXISTS $tableSchema');
  }

  SqlStatement _createMetadataTableStatement(SqlDialect dialect) {
    final metadataTable = _metadataTableSql(dialect);
    return switch (dialect) {
      SqlDialect.sqlite => sql('''
        CREATE TABLE IF NOT EXISTS $metadataTable (
          version TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        '''),
      SqlDialect.postgres => sql('''
        CREATE TABLE IF NOT EXISTS $metadataTable (
          version TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        '''),
    };
  }

  SqlStatement _selectAppliedMigrationsStatement() {
    final metadataTable = _metadataTableSql(pool.dialect);
    return sql('''
      SELECT version, name, applied_at
      FROM $metadataTable
      ORDER BY applied_at ASC, version ASC
      ''');
  }

  SqlStatement _insertAppliedMigrationStatement(
    SqlDialect dialect,
    SqlMigration migration,
  ) {
    final metadataTable = _metadataTableSql(dialect);
    return switch (dialect) {
      SqlDialect.sqlite => SqlStatement.positional(
        'INSERT INTO $metadataTable (version, name) VALUES (?, ?)',
        [migration.version, migration.name],
      ),
      SqlDialect.postgres => SqlStatement.positional(
        'INSERT INTO $metadataTable (version, name) VALUES (\$1, \$2)',
        [migration.version, migration.name],
      ),
    };
  }

  SqlStatement _deleteAppliedMigrationStatement(
    SqlDialect dialect,
    String version,
  ) {
    final metadataTable = _metadataTableSql(dialect);
    return switch (dialect) {
      SqlDialect.sqlite => SqlStatement.positional(
        'DELETE FROM $metadataTable WHERE version = ?',
        [version],
      ),
      SqlDialect.postgres => SqlStatement.positional(
        'DELETE FROM $metadataTable WHERE version = \$1',
        [version],
      ),
    };
  }

  String _metadataTableSql(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => '$tableSchema.$tableName',
      SqlDialect.sqlite => tableName,
    };
  }
}

void _validateTableName(String tableName) {
  _validateSqlIdentifier(tableName, 'tableName');
}

void _validateSqlIdentifier(String value, String argumentName) {
  if (!_sqlIdentifierPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      argumentName,
      'Metadata table identifiers must be simple SQL identifiers.',
    );
  }
}

void _validateMigrations(List<SqlMigration> migrations) {
  final versions = <String>{};

  for (final migration in migrations) {
    if (migration.version.isEmpty) {
      throw ArgumentError.value(
        migration.version,
        'migrations',
        'Migration versions must not be empty.',
      );
    }
    if (migration.name.isEmpty) {
      throw ArgumentError.value(
        migration.name,
        'migrations',
        'Migration names must not be empty.',
      );
    }
    if (!versions.add(migration.version)) {
      throw ArgumentError.value(
        migrations,
        'migrations',
        'Duplicate migration version "${migration.version}".',
      );
    }
  }
}

DateTime _readAppliedAt(Object? value) {
  return switch (value) {
    final DateTime appliedAt => appliedAt.toUtc(),
    final String appliedAt => DateTime.parse(
      appliedAt.contains('T')
          ? appliedAt
          : '${appliedAt.replaceFirst(' ', 'T')}Z',
    ).toUtc(),
    final Object other => throw StateError(
      'Unsupported applied_at value type ${other.runtimeType}.',
    ),
    null => throw StateError('Missing applied_at value in migration metadata.'),
  };
}

final _sqlIdentifierPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
