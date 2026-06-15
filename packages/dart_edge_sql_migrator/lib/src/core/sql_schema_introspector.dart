import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'sql_schema_migration.dart';

/// Reads a live database schema into [SqlDatabaseSchema].
abstract interface class SqlSchemaIntrospector {
  /// Returns the database schema visible through [executor].
  Future<SqlDatabaseSchema> introspect(SqlExecutor executor);
}

/// SQLite schema introspector backed by `sqlite_master` and PRAGMA metadata.
final class SqliteSchemaIntrospector implements SqlSchemaIntrospector {
  const SqliteSchemaIntrospector({
    this.excludeTables = const <String>{'migrations'},
  });

  /// Table names that should not appear in the returned app schema.
  final Set<String> excludeTables;

  @override
  Future<SqlDatabaseSchema> introspect(SqlExecutor executor) async {
    if (executor.dialect != SqlDialect.sqlite) {
      throw ArgumentError.value(
        executor.dialect,
        'executor',
        'SqliteSchemaIntrospector requires a SQLite executor.',
      );
    }

    final tableRows = await executor.execute(
      sql('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name
        '''),
    );

    final tables = <SqlTableSchema>[];
    for (final row in tableRows.rows) {
      final tableName = row.read<String>('name');
      if (excludeTables.contains(tableName)) {
        continue;
      }
      tables.add(await _introspectTable(executor, tableName));
    }

    return SqlDatabaseSchema(tables: List.unmodifiable(tables));
  }

  Future<SqlTableSchema> _introspectTable(
    SqlExecutor executor,
    String tableName,
  ) async {
    final indexRows = await executor.execute(
      sql('PRAGMA index_list(${_quoteIdentifier(tableName)})'),
    );
    final uniqueSingleColumnNames = <String>{};
    final indexes = <SqlIndexSchema>[];

    for (final row in indexRows.rows) {
      final indexName = row.read<String>('name');
      final origin = row.readNullable<String>('origin');
      if (origin == 'pk') {
        continue;
      }

      final indexInfo = await executor.execute(
        sql('PRAGMA index_info(${_quoteIdentifier(indexName)})'),
      );
      final columns = [
        for (final indexColumn in indexInfo.rows)
          indexColumn.read<String>('name'),
      ];
      final unique = _readSqliteBool(row['unique']);
      if (unique && columns.length == 1) {
        uniqueSingleColumnNames.add(columns.single);
      }
      indexes.add(
        SqlIndexSchema(
          name: indexName,
          columns: List.unmodifiable(columns),
          unique: unique,
        ),
      );
    }

    final columnRows = await executor.execute(
      sql('PRAGMA table_info(${_quoteIdentifier(tableName)})'),
    );
    final columns = [
      for (final row in columnRows.rows)
        _sqliteColumn(row, uniqueSingleColumnNames: uniqueSingleColumnNames),
    ];

    return SqlTableSchema(
      name: tableName,
      columns: List.unmodifiable(columns),
      indexes: List.unmodifiable(indexes),
    );
  }

  SqlColumnSchema _sqliteColumn(
    SqlRow row, {
    required Set<String> uniqueSingleColumnNames,
  }) {
    final name = row.read<String>('name');
    final primaryKey = _readSqliteBool(row['pk']);
    final notNull = _readSqliteBool(row['notnull']);
    final rawType = row.read<String>('type');
    final type = rawType.isEmpty ? 'TEXT' : rawType.toUpperCase();
    return SqlColumnSchema(
      name: name,
      type: type,
      nullable: !notNull && !primaryKey,
      primaryKey: primaryKey,
      unique: uniqueSingleColumnNames.contains(name),
      defaultExpression: row.readNullable<String>('dflt_value'),
    );
  }
}

/// PostgreSQL schema introspector backed by `information_schema` and
/// `pg_catalog`.
final class PostgresSchemaIntrospector implements SqlSchemaIntrospector {
  const PostgresSchemaIntrospector({
    this.schemas = const <String>['public'],
    this.excludeTables = const <String>{'migrations'},
  });

  /// PostgreSQL schemas to include.
  final List<String> schemas;

  /// Unqualified table names that should not appear in the returned app schema.
  final Set<String> excludeTables;

  @override
  Future<SqlDatabaseSchema> introspect(SqlExecutor executor) async {
    if (executor.dialect != SqlDialect.postgres) {
      throw ArgumentError.value(
        executor.dialect,
        'executor',
        'PostgresSchemaIntrospector requires a PostgreSQL executor.',
      );
    }
    if (schemas.isEmpty) {
      return const SqlDatabaseSchema(tables: []);
    }

    final placeholders = [
      for (var index = 0; index < schemas.length; index += 1) '\$${index + 1}',
    ].join(', ');
    final tableRows = await executor.execute(
      SqlStatement.positional('''
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema IN ($placeholders)
        ORDER BY table_schema, table_name
        ''', schemas),
    );

    final tables = <SqlTableSchema>[];
    for (final row in tableRows.rows) {
      final schema = row.read<String>('table_schema');
      final tableName = row.read<String>('table_name');
      if (excludeTables.contains(tableName)) {
        continue;
      }
      tables.add(await _introspectTable(executor, schema, tableName));
    }

    final routines = await _routines(executor, placeholders);

    return SqlDatabaseSchema(
      tables: List.unmodifiable(tables),
      routines: routines,
    );
  }

  Future<List<SqlRoutineSchema>> _routines(
    SqlExecutor executor,
    String schemaPlaceholders,
  ) async {
    final result = await executor.execute(
      SqlStatement.positional('''
        SELECT
          n.nspname AS routine_schema,
          p.proname AS routine_name,
          pg_get_function_identity_arguments(p.oid) AS identity_arguments,
          pg_get_functiondef(p.oid) AS definition
        FROM pg_proc AS p
        JOIN pg_namespace AS n ON n.oid = p.pronamespace
        WHERE n.nspname IN ($schemaPlaceholders)
          AND p.prokind = 'f'
        ORDER BY n.nspname, p.proname, identity_arguments
        ''', schemas),
    );

    return List.unmodifiable([
      for (final row in result.rows)
        SqlRoutineSchema(
          schema: row.read<String>('routine_schema'),
          name: row.read<String>('routine_name'),
          identityArguments: row.read<String>('identity_arguments'),
          definition: row.read<String>('definition'),
        ),
    ]);
  }

  Future<SqlTableSchema> _introspectTable(
    SqlExecutor executor,
    String schema,
    String tableName,
  ) async {
    final primaryKeyColumns = await _primaryKeyColumns(
      executor,
      schema,
      tableName,
    );
    final indexes = await _indexes(executor, schema, tableName);
    final uniqueSingleColumnNames = {
      for (final index in indexes)
        if (index.unique && index.columns.length == 1) index.columns.single,
    };

    final columnRows = await executor.execute(
      SqlStatement.positional(
        '''
        SELECT column_name, data_type, udt_name, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = \$1
          AND table_name = \$2
        ORDER BY ordinal_position
        ''',
        [schema, tableName],
      ),
    );

    final columns = [
      for (final row in columnRows.rows)
        _postgresColumn(
          row,
          primaryKeyColumns: primaryKeyColumns,
          uniqueSingleColumnNames: uniqueSingleColumnNames,
        ),
    ];

    return SqlTableSchema(
      schema: schema,
      name: tableName,
      columns: List.unmodifiable(columns),
      indexes: List.unmodifiable(indexes),
    );
  }

  Future<Set<String>> _primaryKeyColumns(
    SqlExecutor executor,
    String schema,
    String tableName,
  ) async {
    final result = await executor.execute(
      SqlStatement.positional(
        '''
        SELECT kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
         AND tc.table_schema = kcu.table_schema
         AND tc.table_name = kcu.table_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = \$1
          AND tc.table_name = \$2
        ORDER BY kcu.ordinal_position
        ''',
        [schema, tableName],
      ),
    );
    return {for (final row in result.rows) row.read<String>('column_name')};
  }

  Future<List<SqlIndexSchema>> _indexes(
    SqlExecutor executor,
    String schema,
    String tableName,
  ) async {
    final result = await executor.execute(
      SqlStatement.positional(
        '''
        SELECT
          i.relname AS index_name,
          ix.indisunique AS is_unique,
          ix.indisprimary AS is_primary,
          string_agg(a.attname, ',' ORDER BY keys.ordinality) AS column_names
        FROM pg_class AS t
        JOIN pg_namespace AS n ON n.oid = t.relnamespace
        JOIN pg_index AS ix ON ix.indrelid = t.oid
        JOIN pg_class AS i ON i.oid = ix.indexrelid
        JOIN unnest(ix.indkey) WITH ORDINALITY AS keys(attnum, ordinality)
          ON true
        JOIN pg_attribute AS a
          ON a.attrelid = t.oid
         AND a.attnum = keys.attnum
        WHERE n.nspname = \$1
          AND t.relname = \$2
        GROUP BY i.relname, ix.indisunique, ix.indisprimary
        ORDER BY i.relname
        ''',
        [schema, tableName],
      ),
    );

    return List.unmodifiable([
      for (final row in result.rows)
        if (!_readBool(row['is_primary']))
          SqlIndexSchema(
            name: row.read<String>('index_name'),
            columns: row
                .read<String>('column_names')
                .split(',')
                .where((column) => column.isNotEmpty)
                .toList(growable: false),
            unique: _readBool(row['is_unique']),
          ),
    ]);
  }

  SqlColumnSchema _postgresColumn(
    SqlRow row, {
    required Set<String> primaryKeyColumns,
    required Set<String> uniqueSingleColumnNames,
  }) {
    final name = row.read<String>('column_name');
    final primaryKey = primaryKeyColumns.contains(name);
    return SqlColumnSchema(
      name: name,
      type: _postgresType(
        dataType: row.read<String>('data_type'),
        udtName: row.readNullable<String>('udt_name'),
      ),
      nullable: row.read<String>('is_nullable') == 'YES' && !primaryKey,
      primaryKey: primaryKey,
      unique: uniqueSingleColumnNames.contains(name),
      defaultExpression: row.readNullable<String>('column_default'),
    );
  }

  String _postgresType({required String dataType, required String? udtName}) {
    return switch (dataType) {
      'ARRAY' when udtName != null && udtName.startsWith('_') =>
        '${udtName.substring(1).toUpperCase()}[]',
      'bigint' => 'BIGINT',
      'boolean' => 'BOOLEAN',
      'double precision' => 'DOUBLE PRECISION',
      'integer' => 'INTEGER',
      'json' => 'JSON',
      'jsonb' => 'JSONB',
      'real' => 'REAL',
      'smallint' => 'SMALLINT',
      'text' => 'TEXT',
      'timestamp with time zone' => 'TIMESTAMPTZ',
      'timestamp without time zone' => 'TIMESTAMP',
      'uuid' => 'UUID',
      'USER-DEFINED' when udtName != null => udtName,
      _ => dataType.toUpperCase(),
    };
  }
}

bool _readSqliteBool(Object? value) {
  return switch (value) {
    final int number => number != 0,
    final bool boolean => boolean,
    final String text => text == '1' || text.toLowerCase() == 'true',
    _ => false,
  };
}

bool _readBool(Object? value) {
  return switch (value) {
    final bool boolean => boolean,
    final int number => number != 0,
    final String text =>
      text.toLowerCase() == 't' || text.toLowerCase() == 'true',
    _ => false,
  };
}

String _quoteIdentifier(String identifier) {
  final escaped = identifier.replaceAll('"', '""');
  return '"$escaped"';
}
