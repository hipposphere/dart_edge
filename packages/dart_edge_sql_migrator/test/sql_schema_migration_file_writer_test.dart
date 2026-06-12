import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:test/test.dart';

void main() {
  test(
    'writes a shared migration file when dialect SQL is identical',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dart_edge_sql_schema_writer_shared_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final diff = SqlSchemaDiff.between(
        current: const SqlDatabaseSchema(tables: []),
        desired: const SqlDatabaseSchema(
          tables: [
            SqlTableSchema(
              name: 'users',
              columns: [
                SqlColumnSchema(name: 'id', type: 'INTEGER', primaryKey: true),
              ],
            ),
          ],
        ),
      );

      final files = await SqlSchemaMigrationFileWriter(
        folder: directory.path,
      ).writeFlywayMigration(version: '1', name: 'Create Users', diff: diff);

      expect(files.stem, 'V1__create_users');
      expect(files.files.map((file) => file.uri.pathSegments.last), [
        'V1__create_users.sql',
      ]);
      expect(await files.files.single.readAsString(), '''
CREATE TABLE "users" ("id" INTEGER NOT NULL PRIMARY KEY);''');
    },
  );

  test('writes dialect-specific migration files when SQL differs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_edge_sql_schema_writer_dialect_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final diff = SqlSchemaDiff.between(
      current: const SqlDatabaseSchema(tables: []),
      desired: const SqlDatabaseSchema(
        tables: [
          SqlTableSchema(
            schema: 'app',
            name: 'users',
            columns: [
              SqlColumnSchema(name: 'id', type: 'BIGINT', primaryKey: true),
            ],
          ),
        ],
      ),
    );

    final files = await SqlSchemaMigrationFileWriter(
      folder: directory.path,
    ).writeFlywayMigration(version: '2', name: 'Create Users', diff: diff);

    expect(files.files.map((file) => file.uri.pathSegments.last), {
      'V2__create_users.sqlite.sql',
      'V2__create_users.postgres.sql',
    });

    final sqlite = await File(
      '${directory.path}/V2__create_users.sqlite.sql',
    ).readAsString();
    final postgres = await File(
      '${directory.path}/V2__create_users.postgres.sql',
    ).readAsString();

    expect(sqlite, 'CREATE TABLE "users" ("id" BIGINT NOT NULL PRIMARY KEY);');
    expect(
      postgres,
      'CREATE TABLE "app"."users" ("id" BIGINT NOT NULL PRIMARY KEY);',
    );
  });

  test('writes a migration from an introspected sqlite schema diff', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);
    await pool.execute(
      sql('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)'),
    );

    final current = await const SqliteSchemaIntrospector().introspect(pool);
    final desired = SqlDatabaseSchema(
      tables: [
        SqlTableSchema(
          name: 'users',
          columns: [
            ...current.tables.single.columns,
            const SqlColumnSchema(name: 'nickname', type: 'TEXT'),
          ],
          indexes: current.tables.single.indexes,
        ),
      ],
    );
    final diff = SqlSchemaDiff.between(current: current, desired: desired);

    final directory = await Directory.systemTemp.createTemp(
      'dart_edge_sql_schema_writer_introspected_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final files = await SqlSchemaMigrationFileWriter(
      folder: directory.path,
      dialects: const [SqlDialect.sqlite],
    ).writeFlywayMigration(version: '3', name: 'Add Nickname', diff: diff);

    expect(await files.files.single.readAsString(), '''
ALTER TABLE "users" ADD COLUMN "nickname" TEXT;''');
  });
}
