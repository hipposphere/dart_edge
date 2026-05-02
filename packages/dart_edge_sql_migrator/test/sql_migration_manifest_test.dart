import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test('builds one embedded data asset manifest from a folder', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_edge_sql_migrator_manifest_',
    );
    addTearDown(() => directory.delete(recursive: true));

    await _writeSql(directory, '0002_seed.sql', "SELECT 'seed';");
    await _writeSql(directory, '0001_create.sql', "SELECT 'create';");

    final manifest = await SqlMigrationManifest.fromFolder(
      package: 'app',
      folder: directory.path,
      assetNamePrefix: 'db/migrations',
    );

    expect(manifest.package, 'app');
    expect(manifest.entries.map((entry) => entry.name), [
      'db/migrations/0001_create.sql',
      'db/migrations/0002_seed.sql',
    ]);
    expect(manifest.entries.map((entry) => entry.sql.trim()), [
      "SELECT 'create';",
      "SELECT 'seed';",
    ]);
    expect(manifest.sourceFiles, hasLength(2));

    final outputFile = directory.uri.resolve('generated_manifest.json');
    final asset = await manifest.writeDataAsset(
      name: 'db/migrations_manifest.json',
      file: outputFile,
    );
    expect(asset.id, 'package:app/db/migrations_manifest.json');
    expect(await File.fromUri(outputFile).exists(), isTrue);

    final roundTrip = SqlMigrationManifest.fromJsonString(
      await File.fromUri(outputFile).readAsString(),
    );
    expect(roundTrip.entries.map((entry) => entry.name), [
      'db/migrations/0001_create.sql',
      'db/migrations/0002_seed.sql',
    ]);
    expect(roundTrip.entries.map((entry) => entry.sql.trim()), [
      "SELECT 'create';",
      "SELECT 'seed';",
    ]);
  });

  test('loads migrations from SQL embedded in one manifest', () async {
    final manifest = SqlMigrationManifest(
      package: 'app',
      entries: const [
        SqlMigrationManifestEntry(
          name: 'db/migrations/V2__seed.sql',
          sql: "INSERT INTO users (email) VALUES ('ada@example.com');",
        ),
        SqlMigrationManifestEntry(
          name: 'db/migrations/V1__create_users.sqlite.sql',
          sql: '''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              email TEXT NOT NULL
            );
          ''',
        ),
        SqlMigrationManifestEntry(
          name: 'db/migrations/V1__create_users.postgres.sql',
          sql: '''
            CREATE TABLE users (
              id BIGINT PRIMARY KEY,
              email TEXT NOT NULL
            );
          ''',
        ),
        SqlMigrationManifestEntry(
          name: 'db/migrations/V1__create_users.down.sql',
          sql: 'DROP TABLE users;',
        ),
      ],
    );

    final migrations = manifest.toMigrations(
      sorting: const SqlMigrationFileSorting.flyway(),
    );

    expect(migrations.map((migration) => migration.version), ['1', '2']);
    expect(migrations.map((migration) => migration.name), [
      'create_users',
      'seed',
    ]);
    expect(
      migrations.first.up.byDialect.keys,
      containsAll([SqlDialect.sqlite, SqlDialect.postgres]),
    );
    expect(migrations.first.down.shared.single.sql, 'DROP TABLE users');
  });

  test('creates a migrator from an already-loaded manifest', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final migrator = await DartEdgeSqlMigrator.fromManifest(
      pool: pool,
      manifest: const SqlMigrationManifest(
        package: 'app',
        entries: [
          SqlMigrationManifestEntry(
            name: 'db/migrations/V1__create_users.sql',
            sql: 'CREATE TABLE users (id BIGINT PRIMARY KEY);',
          ),
        ],
      ),
      sorting: const SqlMigrationFileSorting.flyway(),
    );

    expect(migrator.migrations.map((migration) => migration.version), ['1']);
    expect(migrator.migrations.single.name, 'create_users');
  });

  test('creates a migrator from one data asset manifest', () async {
    final pool = _RecordingPool(SqlDialect.postgres);
    final manifest = const SqlMigrationManifest(
      package: 'app',
      entries: [
        SqlMigrationManifestEntry(
          name: 'db/migrations/V1__create_users.sql',
          sql: 'CREATE TABLE users (id BIGINT PRIMARY KEY);',
        ),
      ],
    );

    final migrator = await DartEdgeSqlMigrator.fromDataAsset(
      pool: pool,
      assetId: 'package:app/db/migrations_manifest.json',
      loadString: (assetId) async {
        expect(assetId, 'package:app/db/migrations_manifest.json');
        return manifest.toJsonString();
      },
      sorting: const SqlMigrationFileSorting.flyway(),
    );

    expect(migrator.migrations.map((migration) => migration.version), ['1']);
    expect(migrator.migrations.single.name, 'create_users');
  });
}

Future<void> _writeSql(Directory directory, String name, String contents) {
  return File('${directory.path}/$name').writeAsString(contents);
}

final class _RecordingPool implements SqlPool {
  _RecordingPool(this.dialect);

  @override
  final SqlDialect dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    throw UnsupportedError('No SQL execution needed in this test.');
  }

  @override
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action) {
    throw UnsupportedError('No SQL execution needed in this test.');
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) {
    throw UnsupportedError('No SQL execution needed in this test.');
  }

  @override
  Future<void> close() async {}
}
