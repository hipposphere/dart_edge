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
