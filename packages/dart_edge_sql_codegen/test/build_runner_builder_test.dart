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
    );

    await testBuilder(
      builder,
      <String, String>{
        'test_app|lib/schema.dart_edge_sql.json': jsonEncode(database.toJson()),
      },
      generateFor: const {'test_app|lib/schema.dart_edge_sql.json'},
      outputs: {
        'test_app|lib/schema.dart_edge_sql.g.dart': decodedMatches(
          allOf([
            contains('final class AppSchema'),
            contains('final class UsersRow implements JsonEncodable'),
            contains('final class UsersTable extends SqlTable<'),
            contains('static const schemaRef = JsonSchemaRef<UsersRow>'),
            contains('static const JsonSchemaRegistry jsonSchemas'),
          ]),
        ),
      },
    );
  });
}
