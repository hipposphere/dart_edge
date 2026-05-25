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

## Baselining Existing Databases

If a database was already migrated by another tool, such as Flyway, baseline it
once so Dart Edge records the existing migration history without rerunning SQL:

```dart
final status = await migrator.status();

if (status.canBaseline && shouldBaselineExistingDatabase) {
  await migrator.baselineToVersion('42');
}

await migrator.migrateToLatest();
```

`baselineToVersion` takes the migration version, not the migration name. For a
Flyway-style file named `V42__create_users.sql`, the version is `42` and the
name is `create_users`.

Baselining records Dart Edge metadata rows and SHA-256 checksums, but does not
execute migration SQL. By default, baseline calls fail if Dart Edge already has
applied migration metadata, so the operation is safe to use as a one-time
handoff step. Use `baselineToLatest()` when every configured migration already
exists in the physical schema, or `baselineAppliedVersions([...])` when importing
an external successful-version list that matches the configured migration
prefix.

## Data Asset Migrations

Build hooks can turn the same folder layout into one Dart data asset containing
the full migration manifest:

```dart
import 'package:data_assets/data_assets.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildDataAssets) {
      return;
    }

    final manifest = await SqlMigrationManifest.fromFolder(
      package: input.packageName,
      folder: input.packageRoot.resolve('db/migrations').toFilePath(),
      assetNamePrefix: 'db/migrations',
      sorting: const SqlMigrationFileSorting.flyway(),
    );

    final manifestFile = input.outputDirectory.resolve(
      'sql_migrations_manifest.json',
    );
    final manifestAsset = await manifest.writeDataAsset(
      name: 'db/migrations_manifest.json',
      file: manifestFile,
    );

    output.assets.data.add(manifestAsset);
    for (final file in manifest.sourceFiles) {
      output.dependencies.add(file);
    }
  });
}
```

At runtime, load that one manifest asset through your Dart data-asset string
loader:

```dart
final migrator = await DartEdgeSqlMigrator.fromDataAsset(
  pool: pool,
  assetId: 'package:my_app/db/migrations_manifest.json',
  loadString: loadDataAssetString,
  sorting: const SqlMigrationFileSorting.flyway(),
);
```

## Embedded Dart Manifest Generation

If you want to embed the migration manifest as Dart source instead of a data
asset, use the reusable generator:

```dart
import 'dart:io';

import 'package:dart_edge_sql_migrator/dart_edge_migration_manifest_generator.dart';

Future<void> main() async {
  await const DartEdgeMigrationManifestGenerator().writePackageManifest(
    packageRoot: Directory.current,
    config: const DartEdgeMigrationManifestGeneratorConfig(
      package: 'db_migrator',
      manifestFieldName: 'calloDbMigrationManifest',
      migrationsDirectory: 'migrations',
      outputFile: 'lib/src/embedded_migration_manifest.dart',
      sorting: SqlMigrationFileSorting.flyway(),
    ),
  );
}
```

The generated file contains a `const SqlMigrationManifest`, skips empty `.sql`
files by default, and preserves deterministic filename ordering.

## Main Types

- `DartEdgeSqlMigrator` runs migrations and tracks metadata
- `DartEdgeMigrationManifestGenerator` emits an embedded Dart manifest library
- `SqlMigration` describes one ordered migration
- `SqlMigrationManifest` describes SQL files embedded in one Dart data asset
- `SqlMigrationPlan` contains shared and dialect-specific statements
- `SqlMigrationStatus` reports applied and pending migrations

The migrator records its state in `migrations` by default. For PostgreSQL, that
table is schema-qualified in the default PostgreSQL metadata schema, and the
schema is created with `CREATE SCHEMA IF NOT EXISTS ...`. You can override
`tableSchema:` and `tableName:` as long as both remain simple SQL identifiers.
