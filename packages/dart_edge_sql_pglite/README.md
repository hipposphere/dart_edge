# dart_edge_sql_pglite

PGlite-backed PostgreSQL endpoint for `dart_edge_sql`.

This package starts an embedded PGlite PostgreSQL wire-protocol server through a
native Rust bridge. The returned `PgliteDatabase` implements the
`PgliteEndpoint` contract from `dart_edge_sql`, so it can be handed directly to
`PostgresPool.pglite`.

```dart
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';

Future<void> main() async {
  final pool = PostgresPool.pglite(PgliteDatabase.temporary());

  await pool.execute(sql('CREATE TABLE users (id SERIAL PRIMARY KEY)'));
  final result = await pool.execute(sql('SELECT COUNT(*)::int4 AS count FROM users'));

  print(result.single.read<int>('count'));
  await pool.close();
}
```

`PostgresPool.pglite` uses one native session and closes the PGlite endpoint when
the pool closes.

Bundled PGlite extensions can be enabled when opening the database:

```dart
final pool = PgliteDatabase.temporary(
  extensions: const [PgliteExtension.vector],
).asPostgresPool();

await pool.execute(sql('''
CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  embedding vector(3) NOT NULL
)
'''));
```

Use the SQL extension name for custom bundled extensions, for example
`PgliteExtension('pg_trgm')`. The pgvector extension is exposed as
`PgliteExtension.vector`, which maps to the SQL extension name `vector`.
