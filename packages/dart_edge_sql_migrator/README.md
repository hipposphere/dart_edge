# dart_edge_sql_migrator

SQL migration manager for Dart Edge SQLite and PostgreSQL applications.

This package sits on top of `dart_edge_sql` and gives you a small, explicit
way to:

- define ordered migrations
- inspect applied vs pending migrations
- migrate to latest or to a specific version
- roll back migrations through `down` plans

## Example

```dart
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';

Future<void> main() async {
  final pool = SqliteDatabase.inMemory();
  final migrator = DartEdgeSqlMigrator(
    pool: pool,
    migrations: [
      SqlMigration(
        version: '0001',
        name: 'create_users',
        up: SqlMigrationPlan.sql([
          '''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL
          )
          ''',
        ]),
        down: SqlMigrationPlan.sql([
          'DROP TABLE users',
        ]),
      ),
    ],
  );

  await migrator.migrateToLatest();
  await pool.close();
}
```

## File-Based Migrations

You can also load migrations from a folder:

```dart
final migrator = await DartEdgeSqlMigrator.fromFolder(
  pool: pool,
  folder: 'db/migrations',
  sorting: const SqlMigrationFileSorting.flyway(),
);
```

Supported file naming conventions:

- shared up: `0001_create_users.sql` or `V1__create_users.sql`
- shared down: `0001_create_users.down.sql`
- SQLite-only up/down: `0001_create_users.sqlite.sql`,
  `0001_create_users.down.sqlite.sql`
- PostgreSQL-only up/down: `0001_create_users.postgres.sql`,
  `0001_create_users.down.postgres.sql`

Sorting strategies:

- `SqlMigrationFileSorting.lexicographic()`
- `SqlMigrationFileSorting.flyway()`

The Flyway strategy understands names like `V1__...`, `V2__...`, `V10__...`
and sorts them numerically by version segment rather than as plain strings.

See [example/file_based_sql_migrations.dart](example/file_based_sql_migrations.dart)
for a runnable folder-based example.

## Main Types

- `DartEdgeSqlMigrator` runs migrations and tracks metadata
- `SqlMigration` describes one ordered migration
- `SqlMigrationPlan` contains shared and dialect-specific statements
- `SqlMigrationStatus` reports applied and pending migrations

The migrator records its state in `dart_edge_schema_migrations` by default.
You can override that with the `tableName:` parameter as long as it remains a
simple SQL identifier.
