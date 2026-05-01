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
}
