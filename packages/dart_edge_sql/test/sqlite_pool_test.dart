import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:test/test.dart';

void main() {
  test('closes pools orphaned by an embedder restart', () async {
    final orphanedPool = SqliteDatabase.inMemory();
    await orphanedPool.execute(
      sql('CREATE TABLE orphaned (id INTEGER PRIMARY KEY)'),
    );

    await NativeSqlRuntime.closeAllPools();
    await orphanedPool.close();

    final restartedPool = SqliteDatabase.inMemory();
    addTearDown(restartedPool.close);
    final result = await restartedPool.execute(sql('SELECT 1 AS value'));
    expect(result.single.read<int>('value'), 1);
  });

  test('sqlite pool executes reads and writes', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL
        )
        '''),
    );

    await pool.execute(
      SqlStatement.positional('INSERT INTO users (email) VALUES (?)', [
        'ada@example.com',
      ]),
    );

    final result = await pool.execute(
      SqlStatement.named('SELECT id, email FROM users WHERE email = :email', {
        'email': 'ada@example.com',
      }),
    );

    expect(result.single['email'], 'ada@example.com');
    expect(result.affectedRows, 0);
  });

  test('sqlite pool supports transactions', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
        CREATE TABLE counters (
          id INTEGER PRIMARY KEY,
          value INTEGER NOT NULL
        )
        '''),
    );

    await pool.withTransaction((tx) async {
      await tx.execute(
        SqlStatement.positional(
          'INSERT INTO counters (id, value) VALUES (?, ?)',
          [1, 41],
        ),
      );
      await tx.execute(
        SqlStatement.positional(
          'UPDATE counters SET value = value + 1 WHERE id = ?',
          [1],
        ),
      );
    });

    final result = await pool.execute(sql('SELECT value FROM counters'));
    expect(result.single['value'], 42);
  });

  test('withSession reserves one connection for the action', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);
    await pool.execute(
      sql('CREATE TABLE values_table (value INTEGER NOT NULL)'),
    );

    late SqlSession borrowed;
    await pool.withSession((session) async {
      borrowed = session;
      await session.execute(sql('BEGIN'));
      await session.execute(sql('INSERT INTO values_table (value) VALUES (1)'));
      await session.execute(sql('ROLLBACK'));
    });

    expect(await pool.raw.from('values_table').selectAll().execute(), isEmpty);
    await expectLater(
      borrowed.execute(sql('SELECT 1')),
      throwsA(isA<StateError>()),
    );
  });
}
