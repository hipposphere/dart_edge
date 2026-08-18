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

Flutter hot restart replaces the Dart isolate without running normal Dart
disposal callbacks. PGlite endpoints and their native SQL pools use native
finalizers, so they are released automatically when the old isolate group shuts
down. An embedded debug app can also explicitly release every process-owned
endpoint before reopening its persistent database:

```dart
await PgliteDatabase.closeAll();
final pool = PgliteDatabase.open('.local/pglite').asPostgresPool();
```

`closeAll` first closes the process's native SQL transactions and pools, then
shuts down every PGlite endpoint. Only use it when the current process owns all
of those resources, since active pools and endpoints are closed as well.

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

## Full-text search

PGlite supports PostgreSQL's built-in `tsvector` search without an additional
extension. The shared `dart_edge_sql` helpers create a matching GIN index and
execute ranked queries:

```dart
final pool = PgliteDatabase.temporary().asPostgresPool();

await pool.execute(sql('''
CREATE TABLE documents (id BIGSERIAL PRIMARY KEY, content TEXT NOT NULL)
'''));
await pool.execute(
  PostgresTextSearch.createIndex(
    table: 'documents',
    column: 'content',
    configuration: 'simple',
  ),
);

final matches = await pool.execute(
  PostgresTextSearch.search(
    table: 'documents',
    column: 'content',
    query: 'embedded postgres',
    configuration: 'simple',
  ),
);
```

For BM25 ranking, activate the bundled `pg_textsearch` extension:

```dart
final pool = PgliteDatabase.temporary(
  extensions: const [PgliteExtension.pgTextSearch],
).asPostgresPool();
```

Create BM25 indexes with `USING bm25` and `text_config = 'simple'`. PGlite's
packaged runtime includes the self-contained `simple` configuration; other
configurations require their dictionary files to be available in the runtime.
