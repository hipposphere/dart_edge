import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:test/test.dart';

void main() {
  test('emits row, insert, update, and table classes', () {
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

    final output = emitDartSchema(
      database,
      libraryName: 'app_schema',
      databaseClassName: 'AppSchema',
    );

    expect(output, contains('library app_schema;'));
    expect(output, contains('final class AppSchema {'));
    expect(
      output,
      contains("import 'package:dart_edge_runtime/dart_edge_runtime.dart';"),
    );
    expect(output, contains('static const jsonSchemas = JsonSchemaRegistry('));
    expect(output, contains('final class UsersRow implements JsonEncodable {'));
    expect(
      output,
      contains('final class UsersInsert implements JsonEncodable {'),
    );
    expect(
      output,
      contains('final class UsersUpdate implements JsonEncodable {'),
    );
    expect(
      output,
      contains("static const schemaRef = JsonSchemaRef<UsersRow>('UsersRow');"),
    );
    expect(output, contains('static const jsonSchema = JsonSchemaDefinition('));
    expect(output, contains("ref: schemaRef,"));
    expect(
      output,
      contains(
        'factory UsersRow.fromSqlRow(SqlRow row, {String prefix = \'\'}) => UsersRow(',
      ),
    );
    expect(
      output,
      contains(
        'factory UsersRow.fromJson(Map<String, Object?> json) => UsersRow(',
      ),
    );
    expect(output, contains('final class UsersTable extends SqlTable<'));
    expect(output, contains('static final email = SqlColumn<String>('));
    expect(output, contains('this.id = const SqlValue.absent(),'));
    expect(output, contains('final SqlValue<String?> displayName;'));
    expect(
      output,
      contains(
        "'created_at': <String, Object?>{'type': 'string', 'format': 'date-time'}",
      ),
    );
    expect(output, contains("'required': <String>["));
    expect(output, contains("'created_at': createdAt.toIso8601String(),"));
    expect(output, contains("if (id.isPresent) 'id': id.value,"));
  });
}
