import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:test/test.dart';

void main() {
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
}
