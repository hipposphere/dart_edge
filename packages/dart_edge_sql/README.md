# dart_edge_sql

Native-backed typed SQL layer for Dart Edge.

This package gives you a small cross-database abstraction for executing SQL,
mapping rows into typed models, and composing common queries with a fluent API.
It currently ships native PostgreSQL and SQLite pool implementations.

## Core Concepts

- `SqlPool` and `SqlSession` represent the execution surface
- `SqlTable`, `SqlColumn`, and model classes describe your schema in Dart
- `database.builder` keeps typed query building separate from raw `execute(...)`
- `selectFrom`, `insertInto`, `deleteFrom`, and `updateTable` live on that
  builder facade
- `executeExists()` checks whether a query yields any rows without loading them
- `SqlStatement` and `sql()` cover raw SQL when you want full control

## Example

```dart
import 'package:dart_edge_sql/dart_edge_sql.dart';

Future<void> main() async {
  final pool = SqliteDatabase.inMemory();

  await pool.execute(
    sql('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)'),
  );

  await pool
      .builder
      .insertInto(UsersTable.table)
      .values(const UsersInsert(email: 'ada@example.com'))
      .execute();

  final users = await pool
      .builder
      .selectFrom(UsersTable.table)
      .selectAll()
      .execute();

  print(users.single.email);
  await pool.close();
}
```

See [test/sql_query_builder_test.dart](test/sql_query_builder_test.dart) for a
more complete example with joins, inserts, and updates.
