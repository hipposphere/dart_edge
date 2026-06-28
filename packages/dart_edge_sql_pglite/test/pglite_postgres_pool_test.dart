import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';
import 'package:test/test.dart';

void main() {
  test(
    'opens a temporary PGlite database through PostgresPool.pglite',
    () async {
      final pool = PgliteDatabase.temporary().asPostgresPool();
      addTearDown(pool.close);

      await pool.execute(
        sql('''
        CREATE TABLE users (
          id SERIAL PRIMARY KEY,
          email TEXT NOT NULL
        )
        '''),
      );

      await pool.execute(
        SqlStatement.named('INSERT INTO users (email) VALUES (@email)', {
          'email': 'ada@example.com',
        }),
      );

      final result = await pool.execute(sql('SELECT email FROM users'));

      expect(result.single.read<String>('email'), 'ada@example.com');
    },
  );

  test('opens a temporary PGlite database with pgvector', () async {
    final pool = PgliteDatabase.temporary(
      extensions: const [PgliteExtension.vector],
    ).asPostgresPool();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
      CREATE TABLE items (
        id SERIAL PRIMARY KEY,
        embedding vector(3) NOT NULL
      )
      '''),
    );

    await pool.execute(
      sql('''
      INSERT INTO items (embedding)
      VALUES ('[1,2,3]'::vector), ('[4,5,6]'::vector)
      '''),
    );

    final result = await pool.execute(
      sql('''
      SELECT id
      FROM items
      ORDER BY embedding <-> '[1,2,2]'::vector
      LIMIT 1
      '''),
    );

    expect(result.single.read<int>('id'), 1);
  });
}
