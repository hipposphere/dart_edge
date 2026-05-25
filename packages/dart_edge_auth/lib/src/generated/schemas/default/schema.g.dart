import 'package:dart_edge_core/dart_edge_core.dart';
import 'tables/session.g.dart';
import 'tables/user.g.dart';
export 'tables/session.g.dart';
export 'tables/user.g.dart';

final class DefaultSchema {
  const DefaultSchema({this.databaseSchema});

  const DefaultSchema._() : databaseSchema = null;

  final String? databaseSchema;

  static const instance = DefaultSchema._();

  static const schemaName = 'default';

  static const session = DartEdgeAuthSessionsTable.table;

  static const user = DartEdgeAuthUsersTable.table;

  static const List<JsonSchema> schemas = <JsonSchema>[
    DartEdgeAuthSessionRow.jsonSchema,
    DartEdgeAuthSessionInsert.jsonSchema,
    DartEdgeAuthSessionUpdate.jsonSchema,
    DartEdgeAuthUserRow.jsonSchema,
    DartEdgeAuthUserInsert.jsonSchema,
    DartEdgeAuthUserUpdate.jsonSchema,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}

extension DefaultSchemaTables on DefaultSchema {
  DartEdgeAuthSessionsTable get session => DartEdgeAuthSessionsTable.withSchema(
    databaseSchema ?? DartEdgeAuthSessionsTable.table.schema,
  );

  DartEdgeAuthUsersTable get user => DartEdgeAuthUsersTable.withSchema(
    databaseSchema ?? DartEdgeAuthUsersTable.table.schema,
  );
}
