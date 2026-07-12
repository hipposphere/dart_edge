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
    final extensions = await _extensions(executor);

    return SqlDatabaseSchema(
      tables: List.unmodifiable(tables),
      routines: routines,
      extensions: extensions,
    );
  }

  Future<List<SqlExtensionSchema>> _extensions(SqlExecutor executor) async {
    final result = await executor.execute(
      sql('''
        SELECT extname AS extension_name
        FROM pg_extension
        ORDER BY extname
        '''),
    );
    return List.unmodifiable([
      for (final row in result.rows)
        SqlExtensionSchema(name: row.read<String>('extension_name')),
    ]);
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
    final checks = await _checkConstraints(executor, schema, tableName);
    final uniqueConstraints = await _uniqueConstraints(
      executor,
      schema,
      tableName,
    );
    final foreignKeys = await _foreignKeys(executor, schema, tableName);
    final uniqueSingleColumnNames = {
      for (final index in indexes)
        if (index.unique && index.columns.length == 1) index.columns.single,
      for (final constraint in uniqueConstraints)
        if (constraint.columns.length == 1) constraint.columns.single,
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
      checks: checks,
      uniqueConstraints: List.unmodifiable([
        for (final constraint in uniqueConstraints)
          if (constraint.columns.length > 1) constraint,
      ]),
      foreignKeys: foreignKeys,
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
          am.amname AS access_method,
          i.reloptions AS storage_parameters,
          pg_get_expr(ix.indpred, ix.indrelid) AS predicate,
          string_agg(a.attname, ',' ORDER BY keys.ordinality) AS column_names,
          string_agg(
            pg_get_indexdef(i.oid, keys.ordinality::integer, true),
            chr(31)
            ORDER BY keys.ordinality
          ) AS column_definitions
        FROM pg_class AS t
        JOIN pg_namespace AS n ON n.oid = t.relnamespace
        JOIN pg_index AS ix ON ix.indrelid = t.oid
        JOIN pg_class AS i ON i.oid = ix.indexrelid
        JOIN pg_am AS am ON am.oid = i.relam
        LEFT JOIN pg_constraint AS con ON con.conindid = i.oid
        JOIN unnest(ix.indkey) WITH ORDINALITY AS keys(attnum, ordinality)
          ON true
        JOIN pg_attribute AS a
          ON a.attrelid = t.oid
         AND a.attnum = keys.attnum
        WHERE n.nspname = \$1
          AND t.relname = \$2
          AND con.oid IS NULL
        GROUP BY
          i.oid,
          i.relname,
          ix.indisunique,
          ix.indisprimary,
          am.amname,
          i.reloptions,
          ix.indpred,
          ix.indrelid
        ORDER BY i.relname
        ''',
        [schema, tableName],
      ),
    );

    return List.unmodifiable([
      for (final row in result.rows)
        if (!_readBool(row['is_primary'])) _postgresIndex(row),
    ]);
  }

  SqlIndexSchema _postgresIndex(SqlRow row) {
    final accessMethod = row.readNullable<String>('access_method');
    final columns = row
        .read<String>('column_names')
        .split(',')
        .where((column) => column.isNotEmpty)
        .toList(growable: false);
    final definitions = row
        .read<String>('column_definitions')
        .split(String.fromCharCode(31));
    final columnOrders = <String, SqlSortOrder>{};
    final columnNullsOrders = <String, SqlNullsOrder>{};

    for (var index = 0; index < columns.length; index += 1) {
      final column = columns[index];
      final definition = index < definitions.length ? definitions[index] : '';
      final order = _postgresIndexColumnOrder(definition);
      if (order != null) {
        columnOrders[column] = order;
      }
      final nullsOrder = _postgresIndexColumnNullsOrder(definition);
      if (nullsOrder != null) {
        columnNullsOrders[column] = nullsOrder;
      }
    }

    return SqlIndexSchema(
      name: row.read<String>('index_name'),
      columns: columns,
      unique: _readBool(row['is_unique']),
      columnOrders: Map.unmodifiable(columnOrders),
      columnNullsOrders: Map.unmodifiable(columnNullsOrders),
      whereExpression: row.readNullable<String>('predicate'),
      method: switch (accessMethod) {
        null || 'btree' => null,
        final method => method,
      },
      storageParameters: Map.unmodifiable(
        _postgresStorageParameters(row['storage_parameters']),
      ),
      postgresOnly: accessMethod != null && accessMethod != 'btree',
    );
  }

  Map<String, Object> _postgresStorageParameters(Object? value) {
    final entries = switch (value) {
      null => const <String>[],
      final List<Object?> value => value.map((entry) => entry.toString()),
      final String value =>
        value
            .replaceFirst(RegExp(r'^\{'), '')
            .replaceFirst(RegExp(r'\}$'), '')
            .split(','),
      final Object value => <String>[value.toString()],
    };
    return <String, Object>{
      for (final entry in entries)
        if (entry.contains('='))
          entry.substring(0, entry.indexOf('=')): entry.substring(
            entry.indexOf('=') + 1,
          ),
    };
  }

  SqlSortOrder? _postgresIndexColumnOrder(String definition) {
    if (RegExp(r'\bDESC\b', caseSensitive: false).hasMatch(definition)) {
      return SqlSortOrder.descending;
    }
    if (RegExp(r'\bASC\b', caseSensitive: false).hasMatch(definition)) {
      return SqlSortOrder.ascending;
    }
    return null;
  }

  SqlNullsOrder? _postgresIndexColumnNullsOrder(String definition) {
    if (RegExp(
      r'\bNULLS\s+FIRST\b',
      caseSensitive: false,
    ).hasMatch(definition)) {
      return SqlNullsOrder.first;
    }
    if (RegExp(
      r'\bNULLS\s+LAST\b',
      caseSensitive: false,
    ).hasMatch(definition)) {
      return SqlNullsOrder.last;
    }
    return null;
  }

  Future<List<SqlCheckConstraintSchema>> _checkConstraints(
    SqlExecutor executor,
    String schema,
    String tableName,
  ) async {
    final result = await executor.execute(
      SqlStatement.positional(
        '''
        SELECT
          con.conname AS constraint_name,
          pg_get_constraintdef(con.oid, true) AS constraint_definition
        FROM pg_constraint AS con
        JOIN pg_class AS rel ON rel.oid = con.conrelid
        JOIN pg_namespace AS nsp ON nsp.oid = rel.relnamespace
        WHERE con.contype = 'c'
          AND nsp.nspname = \$1
          AND rel.relname = \$2
        ORDER BY con.conname
        ''',
        [schema, tableName],
      ),
    );

    return List.unmodifiable([
      for (final row in result.rows)
        SqlCheckConstraintSchema(
          name: row.read<String>('constraint_name'),
          expression: _postgresCheckExpression(
            row.read<String>('constraint_definition'),
          ),
        ),
    ]);
  }

  Future<List<SqlUniqueConstraintSchema>> _uniqueConstraints(
    SqlExecutor executor,
    String schema,
    String tableName,
  ) async {
    final result = await executor.execute(
      SqlStatement.positional(
        '''
        SELECT
          con.conname AS constraint_name,
          string_agg(att.attname, ',' ORDER BY keys.ordinality) AS column_names
        FROM pg_constraint AS con
        JOIN pg_class AS rel ON rel.oid = con.conrelid
        JOIN pg_namespace AS nsp ON nsp.oid = rel.relnamespace
        JOIN unnest(con.conkey) WITH ORDINALITY AS keys(attnum, ordinality)
          ON true
        JOIN pg_attribute AS att
          ON att.attrelid = rel.oid
         AND att.attnum = keys.attnum
        WHERE con.contype = 'u'
          AND nsp.nspname = \$1
          AND rel.relname = \$2
        GROUP BY con.conname
        ORDER BY con.conname
        ''',
        [schema, tableName],
      ),
    );

    return List.unmodifiable([
      for (final row in result.rows)
        SqlUniqueConstraintSchema(
          name: row.read<String>('constraint_name'),
          columns: row
              .read<String>('column_names')
              .split(',')
              .where((column) => column.isNotEmpty)
              .toList(growable: false),
        ),
    ]);
  }

  Future<List<SqlForeignKeyConstraintSchema>> _foreignKeys(
    SqlExecutor executor,
    String schema,
    String tableName,
  ) async {
    final result = await executor.execute(
      SqlStatement.positional(
        '''
        SELECT
          con.conname AS constraint_name,
          referenced_schema.nspname AS referenced_schema,
          referenced_table.relname AS referenced_table,
          con.confdeltype AS on_delete,
          con.confupdtype AS on_update,
          string_agg(local_att.attname, ',' ORDER BY local_keys.ordinality)
            AS column_names,
          string_agg(referenced_att.attname, ',' ORDER BY local_keys.ordinality)
            AS referenced_column_names
        FROM pg_constraint AS con
        JOIN pg_class AS rel ON rel.oid = con.conrelid
        JOIN pg_namespace AS nsp ON nsp.oid = rel.relnamespace
        JOIN pg_class AS referenced_table ON referenced_table.oid = con.confrelid
        JOIN pg_namespace AS referenced_schema
          ON referenced_schema.oid = referenced_table.relnamespace
        JOIN unnest(con.conkey) WITH ORDINALITY AS local_keys(attnum, ordinality)
          ON true
        JOIN unnest(con.confkey) WITH ORDINALITY AS referenced_keys(attnum, ordinality)
          ON referenced_keys.ordinality = local_keys.ordinality
        JOIN pg_attribute AS local_att
          ON local_att.attrelid = rel.oid
         AND local_att.attnum = local_keys.attnum
        JOIN pg_attribute AS referenced_att
          ON referenced_att.attrelid = referenced_table.oid
         AND referenced_att.attnum = referenced_keys.attnum
        WHERE con.contype = 'f'
          AND nsp.nspname = \$1
          AND rel.relname = \$2
        GROUP BY
          con.conname,
          referenced_schema.nspname,
          referenced_table.relname,
          con.confdeltype,
          con.confupdtype
        ORDER BY con.conname
        ''',
        [schema, tableName],
      ),
    );

    return List.unmodifiable([
      for (final row in result.rows)
        SqlForeignKeyConstraintSchema(
          name: row.read<String>('constraint_name'),
          columns: row
              .read<String>('column_names')
              .split(',')
              .where((column) => column.isNotEmpty)
              .toList(growable: false),
          referencesSchema: row.read<String>('referenced_schema'),
          referencesTable: row.read<String>('referenced_table'),
          referencesColumns: row
              .read<String>('referenced_column_names')
              .split(',')
              .where((column) => column.isNotEmpty)
              .toList(growable: false),
          onDelete: _postgresForeignKeyAction(
            row.readNullable<String>('on_delete'),
          ),
          onUpdate: _postgresForeignKeyAction(
            row.readNullable<String>('on_update'),
          ),
        ),
    ]);
  }

  SqlForeignKeyAction? _postgresForeignKeyAction(String? value) {
    return switch (value) {
      'a' || null => null,
      'r' => SqlForeignKeyAction.restrict,
      'c' => SqlForeignKeyAction.cascade,
      'n' => SqlForeignKeyAction.setNull,
      'd' => SqlForeignKeyAction.setDefault,
      _ => null,
    };
  }

  String _postgresCheckExpression(String definition) {
    final trimmed = definition.trim();
    if (!trimmed.startsWith(RegExp('CHECK\\s*\\(', caseSensitive: false))) {
      return trimmed;
    }

    final openIndex = trimmed.indexOf('(');
    final content = trimmed.substring(openIndex + 1);
    if (!content.endsWith(')')) {
      return content;
    }
    return _stripOuterParentheses(
      content.substring(0, content.length - 1),
    ).trim();
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

String _stripOuterParentheses(String expression) {
  var current = expression.trim();
  while (current.length >= 2 &&
      current.startsWith('(') &&
      current.endsWith(')') &&
      _outerParenthesesWrapWholeExpression(current)) {
    current = current.substring(1, current.length - 1).trim();
  }
  return current;
}

bool _outerParenthesesWrapWholeExpression(String expression) {
  var depth = 0;
  for (var index = 0; index < expression.length; index += 1) {
    final character = expression[index];
    if (character == '(') {
      depth += 1;
    } else if (character == ')') {
      depth -= 1;
      if (depth == 0 && index != expression.length - 1) {
        return false;
      }
      if (depth < 0) {
        return false;
      }
    }
  }
  return depth == 0;
}
