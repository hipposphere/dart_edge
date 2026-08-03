# dart_edge_sql_pgrust

Managed experimental [pgrust](https://github.com/malisper/pgrust) endpoint for
`dart_edge_sql`.

This package initializes a PostgreSQL 18 data directory, starts pgrust as a
child process, waits for its PostgreSQL wire-protocol port, and exposes the
server through `PostgresPool`. Closing the pool shuts down the child process.

pgrust explicitly is not production ready. Use this package for disposable
development databases, compatibility tests, demonstrations, and performance
experiments where data loss is acceptable. Keep production and irreplaceable
data on PostgreSQL.

## Requirements

- Linux or macOS.
- A pgrust executable supplied explicitly, available as `pgrust` on `PATH`, or
  selected with `PGRUST_EXECUTABLE`.
- PostgreSQL 18's `initdb`, available on `PATH` or selected with
  `PGRUST_INITDB_EXECUTABLE`.
- pgrust's PostgreSQL share and timezone data configured through
  `PGRUST_PGSHAREDIR` and `PGRUST_TZDIR` when the executable cannot discover
  them itself.

The package does not download, compile, or redistribute pgrust. pgrust is a
separate AGPL-3.0 project and does not currently support PostgreSQL extensions.

## Temporary database

```dart
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pgrust/dart_edge_sql_pgrust.dart';

Future<void> main() async {
  final database = await PgrustDatabase.temporary(
    executable: '/path/to/pgrust-0.2-macos-arm64',
    initdbExecutable: '/opt/homebrew/opt/postgresql@18/bin/initdb',
    postgresShareDirectory: '/opt/homebrew/opt/postgresql@18/share/postgresql',
    timezoneDirectory:
        '/opt/homebrew/opt/postgresql@18/share/postgresql/timezone',
  );
  final pool = database.asPostgresPool();

  await pool.execute(sql('CREATE TABLE experiments (id BIGSERIAL PRIMARY KEY)'));
  await pool.close();
}
```

The temporary data directory is deleted after `pool.close()`.

## Persistent experimental database

```dart
final database = await PgrustDatabase.open(
  '.local/pgrust',
  executable: '/path/to/pgrust',
);
final pool = database.asPostgresPool(maxSessions: 4);
```

An empty directory is initialized automatically. An existing data directory
must contain `PG_VERSION`; non-empty uninitialized directories are rejected.
Persistent directories are never deleted by the package.

For diagnostics, inspect `database.logs`, `database.processId`, and
`database.exitCode`.
