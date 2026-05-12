import 'dart:io';

import 'package:dart_edge_sql_migrator/dart_edge_migration_manifest_generator.dart';
import 'package:test/test.dart';

void main() {
  test('generates reusable embedded migration manifest source', () async {
    final packageRoot = await Directory.systemTemp.createTemp(
      'dart_edge_sql_migrator_generator_',
    );
    addTearDown(() => packageRoot.delete(recursive: true));

    final migrations = Directory('${packageRoot.path}/migrations');
    await migrations.create();
    await _writeSql(migrations, 'V2__seed.sql', "SELECT 'seed';");
    await _writeSql(migrations, 'empty.sql', '  \n');
    await _writeSql(migrations, 'V1__create_users.sql', "SELECT 'create';");

    final output = await const DartEdgeMigrationManifestGenerator()
        .writePackageManifest(
          packageRoot: packageRoot,
          config: const DartEdgeMigrationManifestGeneratorConfig(
            package: 'db_migrator',
            manifestFieldName: 'calloDbMigrationManifest',
            sorting: SqlMigrationFileSorting.flyway(),
          ),
        );

    expect(
      output.path,
      '${packageRoot.path}/lib/src/embedded_migration_manifest.dart',
    );

    final source = await output.readAsString();
    expect(source, contains('// tool/generate_migration_manifest.dart'));
    expect(source, contains('// Do not edit by hand.'));
    expect(source, contains('const calloDbMigrationManifest'));
    expect(source, contains("package: 'db_migrator'"));
    expect(source, contains("name: 'migrations/V1__create_users.sql'"));
    expect(source, contains("name: 'migrations/V2__seed.sql'"));
    expect(source, isNot(contains('empty.sql')));
    expect(
      source.indexOf('migrations/V1__create_users.sql'),
      lessThan(source.indexOf('migrations/V2__seed.sql')),
    );
  });

  test('supports custom migration and output paths', () async {
    final packageRoot = await Directory.systemTemp.createTemp(
      'dart_edge_sql_migrator_generator_paths_',
    );
    addTearDown(() => packageRoot.delete(recursive: true));

    final migrations = Directory('${packageRoot.path}/db/migrations');
    await migrations.create(recursive: true);
    await _writeSql(migrations, '0001_create_users.sql', 'SELECT 1;');

    final output = await const DartEdgeMigrationManifestGenerator()
        .writePackageManifest(
          packageRoot: packageRoot,
          config: const DartEdgeMigrationManifestGeneratorConfig(
            package: 'app',
            migrationsDirectory: 'db/migrations',
            outputFile: 'lib/generated/migrations.dart',
            manifestFieldName: 'appMigrationManifest',
            assetNamePrefix: 'database/migrations/',
          ),
        );

    expect(output.path, '${packageRoot.path}/lib/generated/migrations.dart');

    final source = await output.readAsString();
    expect(source, contains('const appMigrationManifest'));
    expect(
      source,
      contains("name: 'database/migrations/0001_create_users.sql'"),
    );
  });
}

Future<void> _writeSql(Directory directory, String name, String contents) {
  return File('${directory.path}/$name').writeAsString(contents);
}
