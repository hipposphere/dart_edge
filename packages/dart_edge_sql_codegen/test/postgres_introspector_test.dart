import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:test/test.dart';

void main() {
  test('defaults to public schema', () {
    final introspector = PostgresIntrospector(
      connectionString: 'postgres://db',
    );

    expect(introspector.schemas, {'public'});
  });

  test('accepts multiple schemas', () {
    final introspector = PostgresIntrospector(
      connectionString: 'postgres://db',
      schemas: {'public', 'tenant'},
    );

    expect(introspector.schemas, {'public', 'tenant'});
  });

  test('normalizes blank schemas back to public', () {
    final introspector = PostgresIntrospector(
      connectionString: 'postgres://db',
      schemas: {' ', ''},
    );

    expect(introspector.schemas, {'public'});
  });

  test('preserves enum and constraint metadata in schema snapshots', () {
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
          constraints: [
            IntrospectedTableConstraint(
              name: 'users_email_key',
              kind: IntrospectedTableConstraintKind.unique,
              columns: ['email'],
            ),
            IntrospectedTableConstraint(
              name: 'users_org_id_fkey',
              kind: IntrospectedTableConstraintKind.foreignKey,
              columns: ['org_id'],
              referencedSchema: 'public',
              referencedTable: 'organizations',
              referencedColumns: ['id'],
            ),
          ],
          columns: [
            IntrospectedColumn(
              name: 'status',
              databaseType: 'user_status',
              dartType: 'UserStatus',
              hasDefault: true,
              defaultExpression: "'active'::user_status",
              enumName: 'user_status',
              enumSchema: 'public',
              enumValues: ['active', 'suspended'],
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

    final roundTrip = IntrospectedDatabase.fromJson(database.toJson());
    final table = roundTrip.tables.single;

    expect(roundTrip.enums.single.values, ['active', 'suspended']);
    expect(table.columns.first.defaultExpression, "'active'::user_status");
    expect(table.columns.first.enumName, 'user_status');
    expect(table.columns.last.constrainedValues, ['admin', 'member']);
    expect(table.constraints.map((constraint) => constraint.kind), [
      IntrospectedTableConstraintKind.unique,
      IntrospectedTableConstraintKind.foreignKey,
    ]);
    expect(table.constraints.last.referencedTable, 'organizations');
  });
}
