# dart_edge_sql

Native-backed typed SQL layer for Dart Edge.

This package gives you a small cross-database abstraction for executing SQL,
mapping rows into typed models, and composing common queries with a fluent API.
It currently ships native PostgreSQL and SQLite pool implementations.

## Core Concepts

- `SqlPool` and `SqlSession` represent the execution surface
- `SqlTable`, `SqlColumn`, and model classes describe your schema in Dart
- `database.typed` composes generated-table queries
- `database.raw` composes catalog and ad hoc raw SQL queries
- `from`, `insertInto`, `deleteFrom`, and `updateTable` live on the typed
  query root
- `executeExists()` checks whether a query yields any rows without loading them
- PostgreSQL row-locking helpers such as `forUpdate(wait: .skipLocked)` cover
  queue-style claims and contention control
- `SqlPredicate.and([...])` and `SqlPredicate.or([...])` compose grouped
  predicates explicitly; in typed contexts Dart dot shorthand allows
  `.and([...])` and `.or([...])`
- `database.raw.eq(...)`, `gt(...)`, `lt(...)`, and `eqRef(...)` cover common
  raw SQL comparisons without hand-writing placeholders
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
      .typed
      .insertInto(UsersTable.table)
      .values(const UsersInsert(email: 'ada@example.com'))
      .execute();

  final users = await pool
      .typed
      .from(UsersTable.table)
      .selectAll()
      .execute();

  print(users.single.email);
  await pool.close();
}
```

See [test/sql_query_builder_test.dart](test/sql_query_builder_test.dart) for a
more complete example with joins, inserts, and updates.

Raw query usage is intended for catalog queries, temporary tables, and other
SQL table expressions that do not have generated descriptors:

```dart
final raw = pool.raw;

final rows = await raw
    .from('users', alias: 'u')
    .select([
      '"u"."id" AS "id"',
      'lower("u"."email") AS "email"',
    ])
    .where(raw.eq('"u"."email"', 'ada@example.com'))
    .execute();
```

PostgreSQL row locks are available on typed and raw select builders. Run these
queries inside `withTransaction` when the lock must protect follow-up work:

```dart
final jobs = await pool.withTransaction((tx) {
  return tx.typed
      .from(JobsTable.table)
      .where(JobsTable.status.equals('queued'))
      .orderBy(JobsTable.createdAt.asc())
      .limit(10)
      .forUpdate(wait: .skipLocked)
      .selectAll()
      .execute();
});
```

## Native Integration

Most code should import `package:dart_edge_sql/dart_edge_sql.dart`. Sibling
native-backed Dart Edge packages that need to share an existing SQL pool handle
can import `package:dart_edge_sql/dart_edge_sql_native.dart` for the public
native callback pointers instead of reaching into `lib/src`.
