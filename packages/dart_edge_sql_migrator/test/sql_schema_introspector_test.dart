import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test('introspects sqlite tables, columns, and indexes', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          email TEXT NOT NULL DEFAULT 'unknown@example.com',
          nickname TEXT
        )
        '''),
    );
    await pool.execute(
      sql('CREATE UNIQUE INDEX users_email_key ON users (email)'),
    );

    final schema = await const SqliteSchemaIntrospector().introspect(pool);

    expect(schema.tables, hasLength(1));
    final users = schema.tables.single;
    expect(users.name, 'users');
    expect(users.schema, isNull);
    expect(users.columns.map((column) => column.name), [
      'id',
      'email',
      'nickname',
    ]);

    final id = users.columns[0];
    expect(id.type, 'INTEGER');
    expect(id.nullable, isFalse);
    expect(id.primaryKey, isTrue);

    final email = users.columns[1];
    expect(email.type, 'TEXT');
    expect(email.nullable, isFalse);
    expect(email.unique, isTrue);
    expect(email.defaultExpression, "'unknown@example.com'");

    expect(users.indexes.single.name, 'users_email_key');
    expect(users.indexes.single.columns, ['email']);
    expect(users.indexes.single.unique, isTrue);
  });

  test('rejects sqlite introspection for another dialect', () async {
    final executor = _RecordingExecutor(SqlDialect.postgres);

    expect(
      () => const SqliteSchemaIntrospector().introspect(executor),
      throwsArgumentError,
    );
  });

  test('introspects postgres RPC functions', () async {
    final executor = _RecordingExecutor(SqlDialect.postgres);

    final schema = await const PostgresSchemaIntrospector(
      schemas: ['public'],
    ).introspect(executor);

    expect(schema.tables, isEmpty);
    expect(schema.routines, hasLength(1));
    expect(schema.routines.single.schema, 'public');
    expect(schema.routines.single.name, 'search_users');
    expect(schema.routines.single.identityArguments, 'query text');
    expect(
      schema.routines.single.definition,
      contains('CREATE OR REPLACE FUNCTION public.search_users(query text)'),
    );
  });

  test('introspects postgres check constraints', () async {
    final executor = _PostgresTableRecordingExecutor();

    final schema = await const PostgresSchemaIntrospector(
      schemas: ['workspace'],
    ).introspect(executor);

    expect(schema.tables, hasLength(1));
    final table = schema.tables.single;
    expect(table.schema, 'workspace');
    expect(table.name, 'file_revisions');
    expect(table.checks, hasLength(1));
    expect(table.checks.single.name, 'file_revisions_indexation_status_check');
    expect(
      table.checks.single.expression,
      "indexation_status = ANY (ARRAY['not_indexed'::text, "
      "'pending'::text, 'indexed'::text])",
    );
    expect(table.indexes, hasLength(1));
    expect(table.indexes.single.name, 'idx_file_revisions_active_created');
    expect(table.indexes.single.columns, ['workspace_id', 'created_at']);
    expect(table.indexes.single.columnOrders, {
      'created_at': SqlSortOrder.descending,
    });
    expect(table.indexes.single.columnNullsOrders, {
      'created_at': SqlNullsOrder.last,
    });
    expect(table.indexes.single.whereExpression, 'deleted_at IS NULL');
    expect(table.uniqueConstraints, hasLength(1));
    expect(
      table.uniqueConstraints.single.name,
      'file_revisions_workspace_file_id_key',
    );
    expect(table.uniqueConstraints.single.columns, [
      'workspace_id',
      'file_id',
      'id',
    ]);
    expect(table.foreignKeys, hasLength(1));
    expect(table.foreignKeys.single.name, 'file_revisions_file_id_fkey');
    expect(table.foreignKeys.single.columns, ['file_id']);
    expect(table.foreignKeys.single.referencesSchema, 'workspace');
    expect(table.foreignKeys.single.referencesTable, 'files');
    expect(table.foreignKeys.single.referencesColumns, ['id']);
    expect(table.foreignKeys.single.onDelete, SqlForeignKeyAction.cascade);
  });
}

final class _RecordingExecutor implements SqlExecutor {
  _RecordingExecutor(this.dialect);

  @override
  final SqlDialect dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) async {
    if (dialect == SqlDialect.postgres &&
        statement.sql.contains('FROM information_schema.tables')) {
      return SqlResult();
    }

    if (dialect == SqlDialect.postgres &&
        statement.sql.contains('FROM pg_proc AS p')) {
      return SqlResult(
        rows: [
          SqlRow({
            'routine_schema': 'public',
            'routine_name': 'search_users',
            'identity_arguments': 'query text',
            'definition': '''
CREATE OR REPLACE FUNCTION public.search_users(query text)
 RETURNS SETOF users
 LANGUAGE sql
AS \$function\$
  SELECT * FROM users WHERE email ILIKE '%' || query || '%'
\$function\$
''',
          }),
        ],
      );
    }

    throw UnsupportedError('No SQL execution expected.');
  }
}

final class _PostgresTableRecordingExecutor implements SqlExecutor {
  @override
  SqlDialect get dialect => SqlDialect.postgres;

  @override
  Future<SqlResult> execute(SqlStatement statement) async {
    if (statement.sql.contains('FROM information_schema.tables')) {
      return SqlResult(
        rows: [
          SqlRow({'table_schema': 'workspace', 'table_name': 'file_revisions'}),
        ],
      );
    }

    if (statement.sql.contains(
      'FROM information_schema.table_constraints AS tc',
    )) {
      return SqlResult();
    }

    if (statement.sql.contains('FROM pg_class AS t')) {
      return SqlResult(
        rows: [
          SqlRow({
            'index_name': 'idx_file_revisions_active_created',
            'is_unique': false,
            'is_primary': false,
            'predicate': 'deleted_at IS NULL',
            'column_names': 'workspace_id,created_at',
            'column_definitions':
                'workspace_id\u001Fcreated_at DESC NULLS LAST',
          }),
        ],
      );
    }

    if (statement.sql.contains('pg_get_constraintdef')) {
      return SqlResult(
        rows: [
          SqlRow({
            'constraint_name': 'file_revisions_indexation_status_check',
            'constraint_definition':
                "CHECK ((indexation_status = ANY (ARRAY['not_indexed'::text, "
                "'pending'::text, 'indexed'::text])))",
          }),
        ],
      );
    }

    if (statement.sql.contains("con.contype = 'u'")) {
      return SqlResult(
        rows: [
          SqlRow({
            'constraint_name': 'file_revisions_workspace_file_id_key',
            'column_names': 'workspace_id,file_id,id',
          }),
        ],
      );
    }

    if (statement.sql.contains("con.contype = 'f'")) {
      return SqlResult(
        rows: [
          SqlRow({
            'constraint_name': 'file_revisions_file_id_fkey',
            'referenced_schema': 'workspace',
            'referenced_table': 'files',
            'on_delete': 'c',
            'on_update': 'a',
            'column_names': 'file_id',
            'referenced_column_names': 'id',
          }),
        ],
      );
    }

    if (statement.sql.contains('FROM information_schema.columns')) {
      return SqlResult(
        rows: [
          SqlRow({
            'column_name': 'indexation_status',
            'data_type': 'text',
            'udt_name': 'text',
            'is_nullable': 'NO',
            'column_default': "'not_indexed'::text",
          }),
        ],
      );
    }

    if (statement.sql.contains('FROM pg_proc AS p')) {
      return SqlResult();
    }

    throw UnsupportedError('Unexpected SQL: ${statement.sql}');
  }
}
