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
      SqlStatement.named(
        '''
      INSERT INTO items (embedding)
      VALUES (@first::vector), (@second::vector)
      ''',
        {
          'first': SqlVector([1, 2, 3]),
          'second': SqlVector([4, 5, 6]),
        },
      ),
    );

    final result = await pool.execute(
      SqlStatement.named(
        '''
      SELECT id, embedding
      FROM items
      ORDER BY embedding <-> @query::vector
      LIMIT 1
      ''',
        {
          'query': SqlVector([1, 2, 2]),
        },
      ),
    );

    expect(result.single.read<int>('id'), 1);
    expect(result.single.read<SqlVector>('embedding'), SqlVector([1, 2, 3]));
  });

  test('opens a temporary PGlite database with lossless decimals', () async {
    final pool = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
      CREATE TABLE invoices (
        id SERIAL PRIMARY KEY,
        amount numeric(12, 4) NOT NULL
      )
      '''),
    );

    await pool.execute(
      SqlStatement.named('INSERT INTO invoices (amount) VALUES (@amount)', {
        'amount': SqlDecimal('123.4500'),
      }),
    );

    final result = await pool.execute(
      sql('SELECT amount FROM invoices WHERE id = 1'),
    );

    expect(result.single.read<SqlDecimal>('amount'), SqlDecimal('123.4500'));
  });
}
