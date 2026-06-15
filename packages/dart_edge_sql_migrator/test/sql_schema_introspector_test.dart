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
