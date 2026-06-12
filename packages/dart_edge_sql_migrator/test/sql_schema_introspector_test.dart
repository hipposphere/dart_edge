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
}

final class _RecordingExecutor implements SqlExecutor {
  _RecordingExecutor(this.dialect);

  @override
  final SqlDialect dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    throw UnsupportedError('No SQL execution expected.');
  }
}
