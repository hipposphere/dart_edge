import 'dart:io';

import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:test/test.dart';

void main() {
  test('emits a structured schema tree without library directives', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'users',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'INTEGER',
              dartType: 'int',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'email',
              databaseType: 'TEXT',
              dartType: 'String',
            ),
            IntrospectedColumn(
              name: 'display_name',
              databaseType: 'TEXT',
              dartType: 'String',
              nullable: true,
            ),
            IntrospectedColumn(
              name: 'created_at',
              databaseType: 'TEXT',
              dartType: 'DateTime',
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');

    expect(emission.entrypointFileName, 'app_schema.dart');
    expect(
      emission.files.map((file) => file.relativePath),
      containsAll(<String>[
        'app_schema.dart',
        'schemas/default/schema.dart',
        'schemas/default/tables/users.dart',
      ]),
    );
    expect(
      emission.directories,
      containsAll(<String>[
        'schemas/default',
        'schemas/default/tables',
        'schemas/default/enums',
      ]),
    );

    final entrypoint = emission.fileAt('app_schema.dart').contents;
    final defaultSchema = emission
        .fileAt('schemas/default/schema.dart')
        .contents;
    final usersTable = emission
        .fileAt('schemas/default/tables/users.dart')
        .contents;

    expect(entrypoint, isNot(contains(RegExp(r'^library\s', multiLine: true))));
    expect(entrypoint, contains('final class AppSchema {'));
    expect(
      entrypoint,
      contains('static const defaultSchema = DefaultSchema.instance;'),
    );
    expect(entrypoint, contains('...DefaultSchema.schemas,'));

    expect(defaultSchema, contains('final class DefaultSchema {'));
    expect(defaultSchema, contains("static const schemaName = 'default';"));
    expect(defaultSchema, contains('static const users = UsersTable.table;'));
    expect(
      defaultSchema,
      contains('static const jsonSchemas = JsonSchemaRegistry('),
    );
    expect(defaultSchema, contains('static const schemas = <JsonSchema>['));

    expect(usersTable, isNot(contains(RegExp(r'^library\s', multiLine: true))));
    expect(
      usersTable,
      contains(
        "import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';",
      ),
    );
    expect(
      usersTable,
      contains('final class UsersRow implements JsonEncodable {'),
    );
    expect(
      usersTable,
      contains('final class UsersInsert implements JsonEncodable {'),
    );
    expect(
      usersTable,
      contains('final class UsersUpdate implements JsonEncodable {'),
    );
    expect(usersTable, contains('final class UsersTable extends SqlTable<'));
    expect(
      usersTable,
      contains("static const schemaRef = JsonSchemaRef<UsersRow>('UsersRow');"),
    );
    expect(
      usersTable,
      contains('static const jsonSchema = JsonSchema.object('),
    );
    expect(
      usersTable,
      contains("'created_at': JsonSchema.string(format: 'date-time'),"),
    );
    expect(usersTable, contains("if (id.isPresent) 'id': id.value,"));
    expect(
      usersTable,
      contains(
        "String toString() => 'UsersRow(id: \$id, email: \$email, displayName: \$displayName, createdAt: \$createdAt)';",
      ),
    );
    expect(
      usersTable,
      contains(
        "String toString() => 'UsersInsert(id: \$id, email: \$email, displayName: \$displayName, createdAt: \$createdAt)';",
      ),
    );
  });

  test('keeps same-named tables isolated by schema', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'users',
          schema: 'public',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'int4',
              dartType: 'int',
              primaryKey: true,
            ),
          ],
        ),
        IntrospectedTable(
          name: 'users',
          schema: 'tenant',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'int4',
              dartType: 'int',
              primaryKey: true,
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');

    expect(
      emission.files.map((file) => file.relativePath),
      containsAll(<String>[
        'schemas/public/schema.dart',
        'schemas/public/tables/users.dart',
        'schemas/tenant/schema.dart',
        'schemas/tenant/tables/users.dart',
      ]),
    );

    final entrypoint = emission.fileAt('app_schema.dart').contents;
    expect(
      entrypoint,
      contains('static const publicSchema = PublicSchema.instance;'),
    );
    expect(
      entrypoint,
      contains('static const tenantSchema = TenantSchema.instance;'),
    );
    expect(
      entrypoint,
      isNot(contains('static const users = UsersTable.table;')),
    );
  });

  test('writeToDirectory clears stale generated files', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'users',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'INTEGER',
              dartType: 'int',
              primaryKey: true,
            ),
          ],
        ),
      ],
    );

    final root = Directory.systemTemp.createTempSync('dart_edge_sql_codegen_');
    addTearDown(() => root.deleteSync(recursive: true));

    final outputDirectory = Directory('${root.path}/generated')..createSync();
    File('${outputDirectory.path}/stale.dart').writeAsStringSync('// stale');
    Directory('${outputDirectory.path}/obsolete')..createSync();

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');

    emission.writeToDirectory(outputDirectory.path);

    expect(File('${outputDirectory.path}/stale.dart').existsSync(), isFalse);
    expect(Directory('${outputDirectory.path}/obsolete').existsSync(), isFalse);
    expect(
      File('${outputDirectory.path}/app_schema.dart').existsSync(),
      isTrue,
    );
    expect(
      Directory('${outputDirectory.path}/schemas/default/enums').existsSync(),
      isTrue,
    );
    expect(
      File(
        '${outputDirectory.path}/schemas/default/tables/users.dart',
      ).existsSync(),
      isTrue,
    );
  });

  test('renames generated column fields that would shadow table members', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'schema_migrations',
          columns: [
            IntrospectedColumn(
              name: 'name',
              databaseType: 'TEXT',
              dartType: 'String',
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database);
    final tableFile = emission
        .fileAt('schemas/default/tables/schema_migrations.dart')
        .contents;

    expect(tableFile, contains('static final nameColumn = SqlColumn<String>('));
    expect(tableFile, contains('nameColumn.asObjectColumn,'));
    expect(
      tableFile,
      contains("@override String get name => 'schema_migrations';"),
    );
  });
}
