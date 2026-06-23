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

    expect(emission.entrypointFileName, 'app_schema.g.dart');
    expect(
      emission.files.map((file) => file.relativePath),
      containsAll(<String>[
        'app_schema.g.dart',
        'schemas/default/schema.g.dart',
        'schemas/default/tables/users.g.dart',
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

    final entrypoint = emission.fileAt('app_schema.g.dart').contents;
    final defaultSchema = emission
        .fileAt('schemas/default/schema.g.dart')
        .contents;
    final usersTable = emission
        .fileAt('schemas/default/tables/users.g.dart')
        .contents;

    expect(entrypoint, isNot(contains(RegExp(r'^library\s', multiLine: true))));
    expect(entrypoint, contains('final class AppSchema {'));
    expect(
      entrypoint,
      contains('static const defaultSchema = DefaultSchema.instance;'),
    );
    expect(entrypoint, contains('...DefaultSchema.schemas,'));

    expect(defaultSchema, contains('final class DefaultSchema {'));
    expect(
      defaultSchema,
      contains('const DefaultSchema({this.databaseSchema});'),
    );
    expect(defaultSchema, contains('final String? databaseSchema;'));
    expect(defaultSchema, contains("static const schemaName = 'default';"));
    expect(defaultSchema, contains('static const users = UsersTable.table;'));
    expect(
      defaultSchema,
      contains('extension DefaultSchemaTables on DefaultSchema'),
    );
    expect(
      defaultSchema,
      contains(
        'UsersTable.withSchema(databaseSchema ?? UsersTable.table.schema)',
      ),
    );
    expect(
      defaultSchema,
      contains(
        'static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(',
      ),
    );
    expect(
      defaultSchema,
      contains('static const List<JsonSchema> schemas = <JsonSchema>['),
    );

    expect(usersTable, isNot(contains(RegExp(r'^library\s', multiLine: true))));
    expect(
      usersTable,
      contains("import 'package:dart_edge_core/dart_edge_core.dart';"),
    );
    expect(
      usersTable,
      isNot(contains("import 'package:dart_edge_sql/dart_edge_sql.dart';")),
    );
    expect(usersTable, contains('const UsersTable.withSchema(this.schema);'));
    expect(usersTable, contains('final String? schema;'));
    expect(usersTable, contains('extension UsersTableColumns on UsersTable'));
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
    expect(usersTable, contains('factory UsersRow.decode(Object? value)'));
    expect(usersTable, contains('factory UsersInsert.decode(Object? value)'));
    expect(usersTable, contains('factory UsersUpdate.decode(Object? value)'));
    expect(
      usersTable,
      contains('factory UsersRow.fromJson(Map<String, Object?> json)'),
    );
    expect(usersTable, contains('final class UsersTable extends SqlTable<'));
    expect(usersTable, contains("static const schemaId = 'UsersRow';"));
    expect(
      usersTable,
      contains('static const schemaRef = JsonSchema.componentRef(schemaId);'),
    );
    expect(
      usersTable,
      contains('static const jsonSchema = JsonSchema.object('),
    );
    expect(usersTable, isNot(contains('ref: schemaRef')));
    expect(usersTable, contains('id: schemaId'));
    expect(
      usersTable,
      contains("'created_at': JsonSchema.string(format: 'date-time')"),
    );
    expect(usersTable, contains('UsersRow copyWith({'));
    expect(usersTable, contains('SqlValue<String?>? displayName,'));
    expect(
      usersTable,
      contains('displayName == null || !displayName.isPresent'),
    );
    expect(usersTable, contains('UsersInsert copyWith({'));
    expect(usersTable, contains('SqlValue<UserId>? id,'));
    expect(usersTable, contains('UsersUpdate copyWith({'));
    expect(usersTable, contains('SqlValue<DateTime>? createdAt,'));
    expect(usersTable, contains("if (id.isPresent) 'id': id.value?.value,"));
    expect(usersTable, contains("databaseType: 'INTEGER',"));
    expect(usersTable, contains("databaseType: 'TEXT',"));
    expect(
      usersTable,
      contains("'created_at': createdAt.value?.toIso8601String(),"),
    );
    expect(
      usersTable,
      contains(
        "'UsersRow(id: \$id, email: \$email, displayName: \$displayName, createdAt: \$createdAt)'",
      ),
    );
    expect(
      usersTable,
      contains(
        "'UsersInsert(id: \$id, email: \$email, displayName: \$displayName, createdAt: \$createdAt)'",
      ),
    );
    expect(_avoidableDoubleQuotedStrings(usersTable), isEmpty);
  });

  test('uses configured formatter page width', () {
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

    final emission = emitDartSchema(
      database,
      databaseClassName: 'AppSchema',
      formatterOptions: const DartSchemaFormatterOptions(pageWidth: 100),
    );

    expect(
      emission.fileAt('app_schema.g.dart').contents,
      contains(
        'static const JsonSchemaRegistry jsonSchemas = '
        'JsonSchemaRegistry(schemas: schemas);',
      ),
    );
  });

  test('emits single-library table models without dart_edge_sql imports', () {
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

    final library = emitDartSchemaLibrary(
      database,
      databaseClassName: 'AppSchema',
    );

    expect(
      library,
      contains("import 'package:dart_edge_core/dart_edge_core.dart';"),
    );
    expect(
      library,
      isNot(contains("import 'package:dart_edge_sql/dart_edge_sql.dart';")),
    );
    expect(library, contains('final class UsersTable extends SqlTable<'));
    expect(library, contains('factory UsersRow.decode(Object? value)'));
    expect(_avoidableDoubleQuotedStrings(library), isEmpty);
  });

  test('emits table descriptors for external row and map models', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'users',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'TEXT',
              dartType: 'String',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'email',
              databaseType: 'TEXT',
              dartType: 'String',
            ),
          ],
        ),
      ],
    );

    final library = emitDartTableDescriptorLibrary(
      database,
      partOf: '../dart_edge_auth.dart',
      schemaClassName: 'DartEdgeAuthSchema',
      naming: DartSchemaNaming(
        modelNameBuilder: (context) => switch (context.kind) {
          DartSchemaModelKind.row => 'DartEdgeAuthUser',
          DartSchemaModelKind.insert => 'Map<String, Object?>',
          DartSchemaModelKind.update => 'Map<String, Object?>',
          DartSchemaModelKind.table => 'DartEdgeAuthUsersTable',
        },
      ),
    );

    expect(library, contains("part of '../dart_edge_auth.dart';"));
    expect(library, contains('final class DartEdgeAuthUsersTable'));
    expect(
      library,
      contains(
        'SqlTable<DartEdgeAuthUser, Map<String, Object?>, '
        'Map<String, Object?>>',
      ),
    );
    expect(library, contains('const DartEdgeAuthUsersTable.withSchema'));
    expect(library, contains('final String? schema;'));
    expect(library, contains('extension DartEdgeAuthUsersTableColumns'));
    expect(
      library,
      contains(
        'Map<String, Object?> encodeInsert(Map<String, Object?> value) => '
        'value;',
      ),
    );
    expect(library, contains('extension DartEdgeAuthSchemaTables'));
    expect(
      library,
      contains(
        'DartEdgeAuthUsersTable.withSchema(\n'
        '    databaseSchema ?? DartEdgeAuthUsersTable.table.schema,\n'
        '  )',
      ),
    );
  });

  test('emits table models without database wrappers', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'users',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'TEXT',
              dartType: 'String',
              primaryKey: true,
            ),
          ],
        ),
      ],
    );

    final library = emitDartTableModelLibrary(
      database,
      partOf: '../dart_edge_auth.dart',
      schemaClassName: 'DartEdgeAuthSchema',
      naming: DartSchemaNaming(
        modelNameBuilder: (context) => switch (context.kind) {
          DartSchemaModelKind.row => 'DartEdgeAuthUserRow',
          DartSchemaModelKind.insert => 'DartEdgeAuthUserInsert',
          DartSchemaModelKind.update => 'DartEdgeAuthUserUpdate',
          DartSchemaModelKind.table => 'DartEdgeAuthUsersTable',
        },
      ),
    );

    expect(library, contains("part of '../dart_edge_auth.dart';"));
    expect(
      library,
      contains('final class DartEdgeAuthUserRow implements JsonEncodable'),
    );
    expect(
      library,
      contains('final class DartEdgeAuthUserInsert implements JsonEncodable'),
    );
    expect(
      library,
      contains('final class DartEdgeAuthUserUpdate implements JsonEncodable'),
    );
    expect(
      library,
      allOf(
        contains('DartEdgeAuthUserRow,'),
        contains('DartEdgeAuthUserInsert,'),
        contains('DartEdgeAuthUserUpdate'),
      ),
    );
    expect(library, isNot(contains('final class GeneratedDatabaseSchema')));
    expect(library, isNot(contains('final class DefaultSchema')));
    expect(library, contains('extension DartEdgeAuthSchemaTables'));
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
        'schemas/public/schema.g.dart',
        'schemas/public/tables/users.g.dart',
        'schemas/tenant/schema.g.dart',
        'schemas/tenant/tables/users.g.dart',
      ]),
    );

    final entrypoint = emission.fileAt('app_schema.g.dart').contents;
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

  test('can prefix generated table models with schema names', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'group',
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
      ],
    );

    final emission = emitDartSchema(
      database,
      databaseClassName: 'AppSchema',
      naming: DartSchemaNaming.schemaPrefixed,
    );
    final publicSchema = emission
        .fileAt('schemas/public/schema.g.dart')
        .contents;
    final groupTable = emission
        .fileAt('schemas/public/tables/group.g.dart')
        .contents;

    expect(
      publicSchema,
      contains('static const group = PublicGroupTable.table;'),
    );
    expect(publicSchema, contains('PublicGroupRow.jsonSchema'));
    expect(
      groupTable,
      contains('final class PublicGroupRow implements JsonEncodable'),
    );
    expect(
      groupTable,
      contains('final class PublicGroupInsert implements JsonEncodable'),
    );
    expect(
      groupTable,
      contains('final class PublicGroupUpdate implements JsonEncodable'),
    );
    expect(groupTable, contains('final class PublicGroupTable'));
    expect(
      groupTable,
      contains(
        'extends SqlTable<PublicGroupRow, PublicGroupInsert, PublicGroupUpdate>',
      ),
    );
    expect(groupTable, contains("static const schemaId = 'PublicGroupRow';"));
  });

  test('prefixes generated table models with schema names by default', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'group',
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
      ],
    );

    final library = emitDartSchemaLibrary(
      database,
      databaseClassName: 'AppSchema',
    );

    expect(library, contains('final class PublicGroupRow'));
    expect(library, contains('static const group = PublicGroupTable.table;'));
  });

  test('can opt into historical unprefixed table model names', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'group',
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
      ],
    );

    final library = emitDartSchemaLibrary(
      database,
      databaseClassName: 'AppSchema',
      naming: DartSchemaNaming.unprefixed,
    );

    expect(library, contains('final class GroupRow'));
    expect(library, contains('static const group = GroupTable.table;'));
  });

  test('accepts a custom table model name builder', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'users',
          schema: 'public',
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

    final library = emitDartSchemaLibrary(
      database,
      databaseClassName: 'AppSchema',
      naming: DartSchemaNaming(
        modelNameBuilder: (context) => switch (context.kind) {
          DartSchemaModelKind.row => 'Db${context.defaultName}',
          DartSchemaModelKind.insert => 'New${context.defaultName}',
          DartSchemaModelKind.update => 'Patch${context.defaultName}',
          DartSchemaModelKind.table => 'Sql${context.defaultName}',
        },
      ),
    );

    expect(library, contains('final class DbUsersRow'));
    expect(library, contains('final class NewUsersInsert'));
    expect(library, contains('final class PatchUsersUpdate'));
    expect(library, contains('final class SqlUsersTable'));
    expect(
      library,
      contains(
        'extends SqlTable<DbUsersRow, NewUsersInsert, PatchUsersUpdate>',
      ),
    );
    expect(library, contains('static const users = SqlUsersTable.table;'));
  });

  test('emits null-aware DateTime JSON encoding for nullable columns', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'sessions',
          schema: 'public',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'text',
              dartType: 'String',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'access_token_expires_at',
              databaseType: 'timestamptz',
              dartType: 'DateTime',
              nullable: true,
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final sessionsTable = emission
        .fileAt('schemas/public/tables/sessions.g.dart')
        .contents;

    expect(
      sessionsTable,
      contains(
        "'access_token_expires_at': "
        'accessTokenExpiresAt?.toIso8601String(),',
      ),
    );
    expect(
      sessionsTable,
      contains(
        "'access_token_expires_at': "
        'accessTokenExpiresAt.value?.toIso8601String(),',
      ),
    );
    expect(
      sessionsTable,
      contains('accessTokenExpiresAt: switch (row.readNullable<Object?>('),
    );
    expect(
      sessionsTable,
      contains('final String value => DateTime.parse(value),'),
    );
  });

  test('can encode Postgres int8 JSON values as strings', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'uploads',
          schema: 'public',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'int8',
              dartType: 'int',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'file_size',
              databaseType: 'int8',
              dartType: 'int',
            ),
            IntrospectedColumn(
              name: 'chunk_count',
              databaseType: 'int4',
              dartType: 'int',
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(
      database,
      databaseClassName: 'AppSchema',
      int8JsonEncoding: SqlInt8JsonEncoding.string,
    );
    final uploadsTable = emission
        .fileAt('schemas/public/tables/uploads.g.dart')
        .contents;

    expect(uploadsTable, contains('final PublicUploadId id;'));
    expect(uploadsTable, contains('final int fileSize;'));
    expect(uploadsTable, contains("'id': JsonSchema.string(format: 'int64')"));
    expect(
      uploadsTable,
      contains("'file_size': JsonSchema.string(format: 'int64')"),
    );
    expect(uploadsTable, contains("'chunk_count': JsonSchema.integer()"));
    expect(uploadsTable, contains("'id': id.value.toString(),"));
    expect(uploadsTable, contains("'file_size': fileSize.toString(),"));
    expect(uploadsTable, contains("'chunk_count': chunkCount,"));
    expect(uploadsTable, contains("id: PublicUploadId(switch (json['id'])"));
    expect(uploadsTable, contains("fileSize: switch (json['file_size'])"));
    expect(uploadsTable, contains('final String value => int.parse(value),'));
    expect(uploadsTable, contains('final num value => value.toInt(),'));
    expect(
      uploadsTable,
      contains("throw FormatException('Invalid file_size: \$value')"),
    );
    expect(
      uploadsTable,
      contains('fileSize.value == null ? null : fileSize.value.toString()'),
    );
  });

  test('does not apply int8 JSON string encoding to SQLite columns', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'uploads',
          columns: [
            IntrospectedColumn(
              name: 'file_size',
              databaseType: 'BIGINT',
              dartType: 'int',
            ),
          ],
        ),
      ],
    );

    final library = emitDartSchemaLibrary(
      database,
      databaseClassName: 'AppSchema',
      int8JsonEncoding: SqlInt8JsonEncoding.string,
    );

    expect(library, contains("'file_size': JsonSchema.integer()"));
    expect(library, contains("'file_size': fileSize"));
    expect(library, isNot(contains("'file_size': fileSize.toString(),")));
  });

  test('emits Postgres enum types and enum-aware table models', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      enums: [
        IntrospectedEnum(
          name: 'user_status',
          schema: 'public',
          values: ['active', 'suspended'],
        ),
      ],
      tables: [
        IntrospectedTable(
          name: 'users',
          schema: 'public',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'text',
              dartType: 'String',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'status',
              databaseType: 'user_status',
              dartType: 'UserStatus',
              enumName: 'user_status',
              enumSchema: 'public',
              enumValues: ['active', 'suspended'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final enumFile = emission.fileAt('schemas/public/enums/user_status.g.dart');
    final schema = emission.fileAt('schemas/public/schema.g.dart').contents;
    final usersTable = emission
        .fileAt('schemas/public/tables/users.g.dart')
        .contents;

    expect(enumFile.contents, contains('enum UserStatus {'));
    expect(enumFile.contents, contains("active('active')"));
    expect(enumFile.contents, contains('static UserStatus fromDatabase'));
    expect(schema, contains("export 'enums/user_status.g.dart';"));
    expect(usersTable, contains("import '../enums/user_status.g.dart';"));
    expect(usersTable, contains('final UserStatus status;'));
    expect(usersTable, contains("static final status = SqlColumn<String>("));
    expect(usersTable, contains("databaseType: 'public.user_status',"));
    expect(usersTable, contains("status: UserStatus.fromDatabase("));
    expect(usersTable, contains("'status': status.value,"));
    expect(
      usersTable,
      contains(
        "'status': JsonSchema.string("
        "enumValues: <String>['active', 'suspended']",
      ),
    );
  });

  test('emits extension types for constrained text columns', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'members',
          schema: 'public',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'int4',
              dartType: 'int',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'role',
              databaseType: 'text',
              dartType: 'String',
              hasDefault: true,
              defaultExpression: "'member'::text",
              constrainedValues: ['admin', 'member'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final membersTable = emission
        .fileAt('schemas/public/tables/members.g.dart')
        .contents;

    expect(
      membersTable,
      contains('extension type const PublicMembersRole._(String value)'),
    );
    expect(
      membersTable,
      contains("static const admin = PublicMembersRole._('admin')"),
    );
    expect(
      membersTable,
      contains("static const member = PublicMembersRole._('member')"),
    );
    expect(membersTable, contains('static PublicMembersRole fromDatabase'));
    expect(membersTable, contains('final PublicMembersRole role;'));
    expect(membersTable, contains("static final role = SqlColumn<String>("));
    expect(membersTable, contains("databaseType: 'text',"));
    expect(membersTable, contains("role: PublicMembersRole.fromDatabase("));
    expect(membersTable, contains("'role': role.value,"));
    expect(
      membersTable,
      contains(
        "'role': JsonSchema.string("
        "enumValues: <String>['admin', 'member']",
      ),
    );
  });

  test('emits extension types for primary and foreign keys by default', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'users',
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
          name: 'notes',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'int4',
              dartType: 'int',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'user_id',
              databaseType: 'int4',
              dartType: 'int',
            ),
          ],
          constraints: [
            IntrospectedTableConstraint(
              name: 'notes_user_id_fkey',
              kind: IntrospectedTableConstraintKind.foreignKey,
              columns: ['user_id'],
              referencedTable: 'users',
              referencedColumns: ['id'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final usersTable = emission
        .fileAt('schemas/default/tables/users.g.dart')
        .contents;
    final notesTable = emission
        .fileAt('schemas/default/tables/notes.g.dart')
        .contents;

    expect(usersTable, contains('extension type const UserId(int value) {}'));
    expect(usersTable, contains('final UserId id;'));
    expect(usersTable, contains("id: UserId(row.read<int>('\${prefix}id'))"));
    expect(usersTable, contains("'id': id.value"));
    expect(usersTable, contains('static final id = SqlColumn<UserId>('));

    expect(notesTable, contains("import 'users.g.dart';"));
    expect(notesTable, contains('extension type const NoteId(int value) {}'));
    expect(notesTable, contains('final NoteId id;'));
    expect(notesTable, contains('final UserId userId;'));
    expect(notesTable, contains("userId: UserId(row.read<int>("));
    expect(notesTable, contains("'user_id': userId.value,"));
    expect(notesTable, contains('static final userId = SqlColumn<UserId>('));
  });

  test('emits extension types for composite foreign key columns', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'workspace',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'uuid',
              dartType: 'String',
              primaryKey: true,
            ),
          ],
        ),
        IntrospectedTable(
          name: 'workspace_issue',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'uuid',
              dartType: 'String',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'workspace_id',
              databaseType: 'uuid',
              dartType: 'String',
            ),
          ],
          constraints: [
            IntrospectedTableConstraint(
              name: 'workspace_issue_workspace_id_fkey',
              kind: IntrospectedTableConstraintKind.foreignKey,
              columns: ['workspace_id'],
              referencedTable: 'workspace',
              referencedColumns: ['id'],
            ),
          ],
        ),
        IntrospectedTable(
          name: 'workspace_issue_assignee',
          columns: [
            IntrospectedColumn(
              name: 'issue_id',
              databaseType: 'uuid',
              dartType: 'String',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'workspace_id',
              databaseType: 'uuid',
              dartType: 'String',
              primaryKey: true,
            ),
          ],
          constraints: [
            IntrospectedTableConstraint(
              name: 'workspace_issue_assignee_issue_workspace_fkey',
              kind: IntrospectedTableConstraintKind.foreignKey,
              columns: ['issue_id', 'workspace_id'],
              referencedTable: 'workspace_issue',
              referencedColumns: ['id', 'workspace_id'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final issueAssigneeTable = emission
        .fileAt('schemas/default/tables/workspace_issue_assignee.g.dart')
        .contents;

    expect(issueAssigneeTable, contains("import 'workspace.g.dart';"));
    expect(issueAssigneeTable, contains("import 'workspace_issue.g.dart';"));
    expect(issueAssigneeTable, isNot(contains('extension type const')));
    expect(issueAssigneeTable, contains('final WorkspaceIssueId issueId;'));
    expect(issueAssigneeTable, contains('final WorkspaceId workspaceId;'));
    expect(
      issueAssigneeTable,
      contains("issueId: WorkspaceIssueId(row.read<String>("),
    );
    expect(
      issueAssigneeTable,
      contains("workspaceId: WorkspaceId(row.read<String>("),
    );
    expect(issueAssigneeTable, contains("'issue_id': issueId.value,"));
    expect(issueAssigneeTable, contains("'workspace_id': workspaceId.value,"));
  });

  test('names primary key extension types after the primary key column', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          schema: 'public',
          name: 'notes',
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
          schema: 'auth',
          name: 'user',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'uuid',
              dartType: 'String',
              primaryKey: true,
            ),
          ],
        ),
        IntrospectedTable(
          schema: 'auth',
          name: 'api_key',
          columns: [
            IntrospectedColumn(
              name: 'key',
              databaseType: 'text',
              dartType: 'String',
              primaryKey: true,
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final notesTable = emission
        .fileAt('schemas/public/tables/notes.g.dart')
        .contents;
    final userTable = emission
        .fileAt('schemas/auth/tables/user.g.dart')
        .contents;
    final apiKeyTable = emission
        .fileAt('schemas/auth/tables/api_key.g.dart')
        .contents;

    expect(
      notesTable,
      contains('extension type const PublicNoteId(int value) {}'),
    );
    expect(
      userTable,
      contains('extension type const AuthUserId(String value) {}'),
    );
    expect(
      apiKeyTable,
      contains('extension type const AuthApiKeyKey(String value) {}'),
    );
  });

  test('reuses referenced primary key type for primary key foreign keys', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          schema: 'public',
          name: 'phone_call',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'text',
              dartType: 'String',
              primaryKey: true,
            ),
          ],
        ),
        IntrospectedTable(
          schema: 'public',
          name: 'phone_call_data',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'text',
              dartType: 'String',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'summary',
              databaseType: 'text',
              dartType: 'String?',
              nullable: true,
            ),
          ],
          constraints: [
            IntrospectedTableConstraint(
              name: 'phone_call_data_id_fkey',
              kind: IntrospectedTableConstraintKind.foreignKey,
              columns: ['id'],
              referencedSchema: 'public',
              referencedTable: 'phone_call',
              referencedColumns: ['id'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final phoneCallTable = emission
        .fileAt('schemas/public/tables/phone_call.g.dart')
        .contents;
    final phoneCallDataTable = emission
        .fileAt('schemas/public/tables/phone_call_data.g.dart')
        .contents;

    expect(
      phoneCallTable,
      contains('extension type const PublicPhoneCallId(String value) {}'),
    );
    expect(phoneCallDataTable, contains("import 'phone_call.g.dart';"));
    expect(
      phoneCallDataTable,
      isNot(contains('extension type const PublicPhoneCallDataId')),
    );
    expect(phoneCallDataTable, contains('final PublicPhoneCallId id;'));
    expect(
      phoneCallDataTable,
      contains("id: PublicPhoneCallId(row.read<String>('\${prefix}id'))"),
    );
    expect(phoneCallDataTable, contains('SqlValue<PublicPhoneCallId>? id,'));
    expect(
      phoneCallDataTable,
      contains('static final id = SqlColumn<PublicPhoneCallId>('),
    );
  });

  test('emits nullable extension types for nullable foreign keys', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'users',
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
          name: 'notes',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'int4',
              dartType: 'int',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'archived_by_id',
              databaseType: 'int4',
              dartType: 'int',
              nullable: true,
            ),
          ],
          constraints: [
            IntrospectedTableConstraint(
              name: 'notes_archived_by_id_fkey',
              kind: IntrospectedTableConstraintKind.foreignKey,
              columns: ['archived_by_id'],
              referencedTable: 'users',
              referencedColumns: ['id'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final notesTable = emission
        .fileAt('schemas/default/tables/notes.g.dart')
        .contents;

    expect(notesTable, contains('final UserId? archivedById;'));
    expect(
      notesTable,
      contains(
        "archivedById: row.readNullable<int>('\${prefix}archived_by_id') == null",
      ),
    );
    expect(
      notesTable,
      contains(": UserId(row.readNullable<int>('\${prefix}archived_by_id')!)"),
    );
    expect(
      notesTable,
      contains("archivedById: json['archived_by_id'] == null"),
    );
    expect(
      notesTable,
      contains(": UserId((json['archived_by_id'] as num).toInt())"),
    );
    expect(notesTable, contains('final UserId? archivedById;'));
    expect(notesTable, contains('final SqlValue<UserId?> archivedById;'));
    expect(notesTable, contains("'archived_by_id': archivedById?.value"));
    expect(
      notesTable,
      contains(
        "if (archivedById.isPresent) 'archived_by_id': archivedById.value?.value",
      ),
    );
    expect(
      notesTable,
      contains('static final archivedById = SqlColumn<UserId>('),
    );
  });

  test('can opt out of primary key extension types', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.sqlite,
      tables: [
        IntrospectedTable(
          name: 'notes',
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

    final library = emitDartSchemaLibrary(
      database,
      primaryKeyExtensionTypes: false,
    );

    expect(library, isNot(contains('extension type const NoteId')));
    expect(library, contains('final int id;'));
    expect(library, contains('static final id = SqlColumn<int>('));
  });

  test('emits configured external primary key types for excluded tables', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          schema: 'public',
          name: 'notes',
          columns: [
            IntrospectedColumn(
              name: 'id',
              databaseType: 'int4',
              dartType: 'int',
              primaryKey: true,
            ),
            IntrospectedColumn(
              name: 'owner_id',
              databaseType: 'uuid',
              dartType: 'String',
            ),
          ],
          constraints: [
            IntrospectedTableConstraint(
              name: 'notes_owner_id_fkey',
              kind: IntrospectedTableConstraintKind.foreignKey,
              columns: ['owner_id'],
              referencedSchema: 'auth',
              referencedTable: 'user',
              referencedColumns: ['id'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(
      database,
      databaseClassName: 'AppSchema',
      externalPrimaryKeys: const {
        'auth.user.id': ExternalPrimaryKeySpec(
          typeName: 'AuthUserId',
          baseDartType: 'String',
        ),
      },
    );
    final externalKeys = emission.fileAt('external_keys.g.dart').contents;
    final notesTable = emission
        .fileAt('schemas/public/tables/notes.g.dart')
        .contents;

    expect(
      externalKeys,
      contains('extension type const AuthUserId(String value) {}'),
    );
    expect(notesTable, contains("import '../../../external_keys.g.dart';"));
    expect(notesTable, contains('final AuthUserId ownerId;'));
    expect(notesTable, contains("ownerId: AuthUserId(row.read<String>("));
    expect(notesTable, contains("'owner_id': ownerId.value"));
    expect(
      notesTable,
      contains('static final ownerId = SqlColumn<AuthUserId>('),
    );
    expect(
      emission.files.map((file) => file.relativePath),
      isNot(contains('schemas/auth/tables/user.g.dart')),
    );
  });

  test('emits configured external primary keys even when unused', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          schema: 'public',
          name: 'notes',
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

    final emission = emitDartSchema(
      database,
      databaseClassName: 'AppSchema',
      externalPrimaryKeys: const {
        'auth.api_key.key': ExternalPrimaryKeySpec(
          typeName: 'AuthApiKeyKey',
          baseDartType: 'String',
        ),
      },
    );

    expect(
      emission.fileAt('external_keys.g.dart').contents,
      contains('extension type const AuthApiKeyKey(String value) {}'),
    );
    expect(
      emission.fileAt('app_schema.g.dart').contents,
      contains("export 'external_keys.g.dart';"),
    );
  });

  test('imports enum types from another schema when needed', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      enums: [
        IntrospectedEnum(
          name: 'order_state',
          schema: 'catalog',
          values: ['open', 'closed'],
        ),
      ],
      tables: [
        IntrospectedTable(
          name: 'orders',
          schema: 'sales',
          columns: [
            IntrospectedColumn(
              name: 'state',
              databaseType: 'order_state',
              dartType: 'OrderState',
              enumName: 'order_state',
              enumSchema: 'catalog',
              enumValues: ['open', 'closed'],
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final ordersTable = emission
        .fileAt('schemas/sales/tables/orders.g.dart')
        .contents;

    expect(
      ordersTable,
      contains("import '../../catalog/enums/order_state.g.dart';"),
    );
  });

  test('emits Postgres routine wrappers by schema', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [],
      routines: [
        IntrospectedRoutine(
          name: 'find_user',
          schema: 'public',
          kind: IntrospectedRoutineKind.function,
          returnDatabaseType: 'record',
          returnDartType: 'Object?',
          returnsSet: true,
          parameters: [
            IntrospectedRoutineParameter(
              name: 'email',
              databaseType: 'text',
              dartType: 'String',
            ),
          ],
        ),
        IntrospectedRoutine(
          name: 'refresh_stats',
          schema: 'public',
          kind: IntrospectedRoutineKind.procedure,
          returnDatabaseType: 'void',
          returnDartType: 'Object?',
          returnsSet: false,
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');

    expect(
      emission.files.map((file) => file.relativePath),
      containsAll(<String>[
        'schemas/public/schema.g.dart',
        'schemas/public/routines/routines.g.dart',
      ]),
    );

    final schema = emission.fileAt('schemas/public/schema.g.dart').contents;
    final routines = emission
        .fileAt('schemas/public/routines/routines.g.dart')
        .contents;

    expect(
      schema,
      contains('static const routines = PublicSchemaRoutines.routines;'),
    );
    expect(routines, contains('final class PublicSchemaRoutines {'));
    expect(
      routines,
      contains("import 'package:dart_edge_core/dart_edge_core.dart';"),
    );
    expect(
      routines,
      isNot(contains("import 'package:dart_edge_sql/dart_edge_sql.dart';")),
    );
    expect(routines, contains('const PublicSchemaRoutines._();'));
    expect(
      routines,
      contains('static const routines = PublicSchemaRoutines._();'),
    );
    expect(routines, contains('Future<SqlResult> findUser('));
    expect(routines, contains('required String email'));
    expect(routines, contains('SELECT * FROM "public"."find_user"(@email)'));
    expect(routines, contains('CALL "public"."refresh_stats"()'));
  });

  test('casts Postgres routine parameters with database-specific types', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [],
      routines: [
        IntrospectedRoutine(
          name: 'user_has_workspace_access',
          schema: 'workspace',
          kind: IntrospectedRoutineKind.function,
          returnDatabaseType: 'bool',
          returnDartType: 'bool',
          parameters: [
            IntrospectedRoutineParameter(
              name: 'p_workspace_id',
              databaseType: 'uuid',
              dartType: 'String',
            ),
            IntrospectedRoutineParameter(
              name: 'p_user_id',
              databaseType: 'text',
              dartType: 'String',
            ),
            IntrospectedRoutineParameter(
              name: 'p_required_roles',
              databaseType: '_text',
              dartType: 'List<Object?>',
            ),
          ],
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');
    final routines = emission
        .fileAt('schemas/workspace/routines/routines.g.dart')
        .contents;

    expect(routines, contains('required String pWorkspaceId'));
    expect(routines, contains('required List<Object?> pRequiredRoles'));
    expect(
      routines,
      contains(
        'SELECT "workspace"."user_has_workspace_access"'
        '(@pWorkspaceId::uuid, @pUserId, @pRequiredRoles::text[]) AS value',
      ),
    );
  });

  test('keeps routine wrappers isolated by schema', () {
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [],
      routines: [
        IntrospectedRoutine(
          name: 'refresh',
          schema: 'public',
          kind: IntrospectedRoutineKind.procedure,
          returnDatabaseType: 'void',
          returnDartType: 'Object?',
        ),
        IntrospectedRoutine(
          name: 'refresh',
          schema: 'tenant',
          kind: IntrospectedRoutineKind.procedure,
          returnDatabaseType: 'void',
          returnDartType: 'Object?',
        ),
      ],
    );

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');

    expect(
      emission.files.map((file) => file.relativePath),
      containsAll(<String>[
        'schemas/public/routines/routines.g.dart',
        'schemas/tenant/routines/routines.g.dart',
      ]),
    );
    expect(
      emission.fileAt('app_schema.g.dart').contents,
      contains('static const tenantSchema = TenantSchema.instance;'),
    );
    expect(
      emission.fileAt('schemas/public/routines/routines.g.dart').contents,
      contains('CALL "public"."refresh"()'),
    );
    expect(
      emission.fileAt('schemas/tenant/routines/routines.g.dart').contents,
      contains('CALL "tenant"."refresh"()'),
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
    Directory('${outputDirectory.path}/obsolete').createSync();

    final emission = emitDartSchema(database, databaseClassName: 'AppSchema');

    emission.writeToDirectory(outputDirectory.path);

    expect(File('${outputDirectory.path}/stale.dart').existsSync(), isFalse);
    expect(Directory('${outputDirectory.path}/obsolete').existsSync(), isFalse);
    expect(
      File('${outputDirectory.path}/app_schema.g.dart').existsSync(),
      isTrue,
    );
    expect(
      Directory('${outputDirectory.path}/schemas/default/enums').existsSync(),
      isTrue,
    );
    expect(
      File(
        '${outputDirectory.path}/schemas/default/tables/users.g.dart',
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
        .fileAt('schemas/default/tables/schema_migrations.g.dart')
        .contents;

    expect(tableFile, contains('static final nameColumn = SqlColumn<String>('));
    expect(tableFile, contains("column<String>('name'"));
    expect(tableFile, contains("String get name => 'schema_migrations';"));
  });
}

List<String> _avoidableDoubleQuotedStrings(String source) {
  final literals = <String>[];
  var index = 0;
  var line = 1;
  while (index < source.length) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    if (char == '\n') {
      line += 1;
      index += 1;
      continue;
    }
    if (char == '/' && next == '/') {
      while (index < source.length && source[index] != '\n') {
        index += 1;
      }
      continue;
    }
    if (char == '/' && next == '*') {
      index += 2;
      while (index < source.length &&
          !(source[index] == '*' &&
              index + 1 < source.length &&
              source[index + 1] == '/')) {
        if (source[index] == '\n') {
          line += 1;
        }
        index += 1;
      }
      index += 2;
      continue;
    }

    var raw = false;
    if ((char == 'r' || char == 'R') && (next == "'" || next == '"')) {
      raw = true;
      index += 1;
    }

    final quote = source[index];
    if (quote != "'" && quote != '"') {
      index += 1;
      continue;
    }

    final start = index;
    final startLine = line;
    final tripleQuote = '$quote$quote$quote';
    final triple = source.startsWith(tripleQuote, index);
    index += triple ? 3 : 1;
    var hasSingleQuote = false;
    var closed = false;
    while (index < source.length) {
      if (!triple && source[index] == '\n') {
        break;
      }
      if (source[index] == '\n') {
        line += 1;
      }
      if (source[index] == "'") {
        hasSingleQuote = true;
      }
      if (!raw && source.codeUnitAt(index) == 92) {
        index += 2;
        continue;
      }
      if (triple
          ? source.startsWith(tripleQuote, index)
          : source[index] == quote) {
        index += triple ? 3 : 1;
        closed = true;
        break;
      }
      index += 1;
    }
    if (closed && quote == '"' && !hasSingleQuote) {
      literals.add('$startLine: ${source.substring(start, index)}');
    }
  }
  return literals;
}
