import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';
import 'package:test/test.dart';

void main() {
  test('closes orphaned endpoints before an embedder restart', () async {
    final directory = await Directory.systemTemp.createTemp('pglite-restart-');
    final firstPool = PgliteDatabase.open(directory.path).asPostgresPool();

    try {
      await firstPool.execute(
        sql('CREATE TABLE restart_test (value TEXT NOT NULL)'),
      );
      await firstPool.execute(
        sql("INSERT INTO restart_test (value) VALUES ('persisted')"),
      );

      await PgliteDatabase.closeAll();

      final restartedPool = PgliteDatabase.open(
        directory.path,
      ).asPostgresPool();
      try {
        final result = await restartedPool.execute(
          sql('SELECT value FROM restart_test'),
        );
        expect(result.single.read<String>('value'), 'persisted');
      } finally {
        await restartedPool.close();
      }
    } finally {
      await firstPool.close();
      await directory.delete(recursive: true);
    }
  });

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

  test('supports BM25 search through pg_textsearch', () async {
    final pool = PgliteDatabase.temporary(
      extensions: const [PgliteExtension.pgTextSearch],
    ).asPostgresPool();
    addTearDown(pool.close);

    await pool.execute(
      sql('CREATE TABLE bm25_documents (content TEXT NOT NULL)'),
    );
    await pool.execute(
      sql('''
      INSERT INTO bm25_documents (content) VALUES
        ('Embedded postgres full-text search'),
        ('A local relational database')
      '''),
    );
    await pool.execute(
      sql('''
      CREATE INDEX bm25_documents_content_idx
      ON bm25_documents USING bm25 (content)
      WITH (text_config = 'simple')
      '''),
    );

    final result = await pool.execute(
      sql('''
      SELECT content, content <@> 'postgres' AS score
      FROM bm25_documents
      ORDER BY score
      LIMIT 1
      '''),
    );

    expect(result.single.read<String>('content'), contains('postgres'));
    expect(result.single.read<double>('score').isFinite, isTrue);
  });

  test('supports ranked built-in PostgreSQL full-text search', () async {
    final pool = PgliteDatabase.temporary().asPostgresPool();
    addTearDown(pool.close);

    await pool.execute(
      sql('''
      CREATE TABLE documents (
        id BIGSERIAL PRIMARY KEY,
        content TEXT NOT NULL
      )
      '''),
    );
    await pool.execute(
      sql('''
      INSERT INTO documents (content) VALUES
        ('PostgreSQL provides reliable relational storage'),
        ('SQLite provides embedded relational storage'),
        ('Embedded PostgreSQL supports local applications')
      '''),
    );
    await pool.execute(
      PostgresTextSearch.createIndex(
        table: 'documents',
        column: 'content',
        configuration: 'simple',
      ),
    );

    final result = await pool.execute(
      PostgresTextSearch.search(
        table: 'documents',
        column: 'content',
        query: 'PostgreSQL',
        configuration: 'simple',
        limit: 2,
      ),
    );

    expect(result.rows, hasLength(2));
    expect(
      result.rows.map((row) => row.read<String>('content')),
      everyElement(contains('PostgreSQL')),
    );
    expect(
      result.rows.map((row) => row.read<double>('search_rank')),
      everyElement(greaterThan(0)),
    );
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
