import 'dart:convert';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_edge_sql_codegen/builder.dart';
import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:test/test.dart';

void main() {
  test('emits a Dart library from a schema snapshot JSON asset', () async {
    final builder = dartEdgeSqlBuilder(
      BuilderOptions(const <String, Object?>{
        'database_class_name': 'AppSchema',
      }),
    );
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
          ],
        ),
      ],
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
      ],
    );

    await testBuilder(
      builder,
      <String, String>{
        'test_app|lib/app_schema.schema.json': jsonEncode(database.toJson()),
      },
      generateFor: const {'test_app|lib/app_schema.schema.json'},
      outputs: {
        'test_app|lib/app_schema.g.dart': decodedMatches(
          allOf([
            contains('final class AppSchema'),
            contains('final class UsersRow implements JsonEncodable'),
            contains('final class UsersInsert implements JsonEncodable'),
            contains('final class UsersUpdate implements JsonEncodable'),
            contains('factory UsersRow.decode(Object? value)'),
            contains('factory UsersInsert.decode(Object? value)'),
            contains('factory UsersUpdate.decode(Object? value)'),
            contains('factory UsersRow.fromJson(Map<String, Object?> json)'),
            contains('final class UsersTable extends SqlTable<'),
            contains('final class PublicSchemaRoutines'),
            contains('Future<SqlResult> findUser('),
            contains("import 'package:dart_edge_core/dart_edge_core.dart';"),
            isNot(
              contains("import 'package:dart_edge_sql/dart_edge_sql.dart';"),
            ),
            contains("static const schemaId = 'UsersRow';"),
            contains(
              'static const schemaRef = JsonSchema.componentRef(schemaId);',
            ),
            isNot(contains('ref: schemaRef')),
            contains('id: schemaId'),
            contains('static const JsonSchemaRegistry jsonSchemas'),
            contains(
              'static const List<SqlKeyManifestEntry> sqlKeyManifest = '
              '<SqlKeyManifestEntry>[',
            ),
            contains('UserId.manifest'),
          ]),
        ),
      },
    );
  });

  test('uses formatter options from builder config', () async {
    final builder = dartEdgeSqlBuilder(
      BuilderOptions(const <String, Object?>{
        'database_class_name': 'AppSchema',
        'page_width': 100,
      }),
    );
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

    await testBuilder(
      builder,
      <String, String>{
        'test_app|lib/app_schema.schema.json': jsonEncode(database.toJson()),
      },
      generateFor: const {'test_app|lib/app_schema.schema.json'},
      outputs: {
        'test_app|lib/app_schema.g.dart': decodedMatches(
          contains(
            'static const JsonSchemaRegistry jsonSchemas = '
            'JsonSchemaRegistry(schemas: schemas);',
          ),
        ),
      },
    );
  });

  test('honors schema-prefixed model naming from builder options', () async {
    final builder = dartEdgeSqlBuilder(
      BuilderOptions(const <String, Object?>{
        'database_class_name': 'AppSchema',
        'model_name_style': 'schema_prefixed',
      }),
    );
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

    await testBuilder(
      builder,
      <String, String>{
        'test_app|lib/app_schema.schema.json': jsonEncode(database.toJson()),
      },
      generateFor: const {'test_app|lib/app_schema.schema.json'},
      outputs: {
        'test_app|lib/app_schema.g.dart': decodedMatches(
          allOf([
            contains('final class PublicGroupRow implements JsonEncodable'),
            contains('final class PublicGroupTable'),
            contains(
              'extends SqlTable<PublicGroupRow, PublicGroupInsert, PublicGroupUpdate>',
            ),
            contains('static const group = PublicGroupTable.table;'),
            contains("static const schemaId = 'PublicGroupRow';"),
            contains('PublicGroupId.manifest'),
          ]),
        ),
      },
    );
  });

  test(
    'honors primary key extension type opt-out from builder options',
    () async {
      final builder = dartEdgeSqlBuilder(
        BuilderOptions(const <String, Object?>{
          'primary_key_extension_types': false,
        }),
      );
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

      await testBuilder(
        builder,
        <String, String>{
          'test_app|lib/app_schema.schema.json': jsonEncode(database.toJson()),
        },
        generateFor: const {'test_app|lib/app_schema.schema.json'},
        outputs: {
          'test_app|lib/app_schema.g.dart': decodedMatches(
            allOf([
              isNot(contains('extension type const NoteId')),
              contains('final int id;'),
              contains('static const id = SqlColumn<int>('),
              contains('static const List<SqlKeyManifestEntry> sqlKeyManifest'),
              contains('<SqlKeyManifestEntry>[];'),
            ]),
          ),
        },
      );
    },
  );

  test('honors int8 JSON encoding from builder options', () async {
    final builder = dartEdgeSqlBuilder(
      BuilderOptions(const <String, Object?>{'int8_json_encoding': 'string'}),
    );
    const database = IntrospectedDatabase(
      dialect: SqlCodegenDialect.postgres,
      tables: [
        IntrospectedTable(
          name: 'uploads',
          schema: 'public',
          columns: [
            IntrospectedColumn(
              name: 'file_size',
              databaseType: 'int8',
              dartType: 'int',
            ),
          ],
        ),
      ],
    );

    await testBuilder(
      builder,
      <String, String>{
        'test_app|lib/app_schema.schema.json': jsonEncode(database.toJson()),
      },
      generateFor: const {'test_app|lib/app_schema.schema.json'},
      outputs: {
        'test_app|lib/app_schema.g.dart': decodedMatches(
          allOf([
            contains("'file_size': JsonSchema.string(format: 'int64')"),
            contains("'file_size': fileSize.toString(),"),
            contains("fileSize: switch (json['file_size'])"),
            contains('static const List<SqlKeyManifestEntry> sqlKeyManifest'),
            contains('<SqlKeyManifestEntry>[];'),
          ]),
        ),
      },
    );
  });

  test('honors external primary key mappings from builder options', () async {
    final builder = dartEdgeSqlBuilder(
      BuilderOptions(const <String, Object?>{
        'external_primary_keys': {
          'auth.user.id': {'type': 'AuthUserId', 'base_type': 'String'},
        },
      }),
    );
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

    await testBuilder(
      builder,
      <String, String>{
        'test_app|lib/app_schema.schema.json': jsonEncode(database.toJson()),
      },
      generateFor: const {'test_app|lib/app_schema.schema.json'},
      outputs: {
        'test_app|lib/app_schema.g.dart': decodedMatches(
          allOf([
            contains('extension type const AuthUserId(String value) {'),
            contains('static const JsonSchema schema = .string('),
            contains("format: 'uuid'"),
            contains('static const JsonSchema schemaNullable = .string('),
            contains('final AuthUserId ownerId;'),
            contains("ownerId: AuthUserId(row.read<String>("),
            contains("'owner_id': AuthUserId.schema"),
            contains("dartType: .value('AuthUserId')"),
            contains('static const ownerId = SqlColumn<AuthUserId>('),
            contains('AuthUserId.manifest'),
            contains('PublicNoteId.manifest'),
          ]),
        ),
      },
    );
  });
}
