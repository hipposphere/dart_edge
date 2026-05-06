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
            contains('final class UsersTable extends SqlTable<'),
            contains('final class PublicSchemaRoutines'),
            contains('Future<SqlResult> findUser('),
            contains("static const schemaId = 'UsersRow';"),
            contains(
              'static const schemaRef = JsonSchema.componentRef(schemaId);',
            ),
            isNot(contains('ref: schemaRef')),
            contains('id: schemaId'),
            contains('static const JsonSchemaRegistry jsonSchemas'),
          ]),
        ),
      },
    );
  });
}
