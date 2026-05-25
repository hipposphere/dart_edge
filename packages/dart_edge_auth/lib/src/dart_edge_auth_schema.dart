part of 'dart_edge_auth.dart';

/// Route result schema registry and table descriptors for Better Auth.
final class DartEdgeAuthSchema {
  const DartEdgeAuthSchema({this.databaseSchema});

  /// Optional database schema that contains the Better Auth tables.
  final String? databaseSchema;

  static const users = DartEdgeAuthUsersTable.table;
  static const sessions = DartEdgeAuthSessionsTable.table;

  static const List<JsonSchema> modelSchemas = <JsonSchema>[
    DartEdgeAuthUser.jsonSchema,
    DartEdgeAuthSession.jsonSchema,
  ];

  static const List<JsonSchema> resultSchemas = <JsonSchema>[
    DartEdgeAuthSignUpResult.jsonSchema,
    DartEdgeAuthSignInResult.jsonSchema,
    DartEdgeAuthSessionResult.jsonSchema,
    DartEdgeAuthUserResult.jsonSchema,
    DartEdgeAuthSessionUserResult.jsonSchema,
    DartEdgeAuthListUsersResult.jsonSchema,
    DartEdgeAuthListSessionsResult.jsonSchema,
    DartEdgeAuthStatusResult.jsonSchema,
    DartEdgeAuthSuccessResult.jsonSchema,
    DartEdgeAuthPermissionResult.jsonSchema,
  ];

  static const List<JsonSchema> schemas = <JsonSchema>[
    ...modelSchemas,
    ...resultSchemas,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}

extension DartEdgeAuthSchemaTables on DartEdgeAuthSchema {
  DartEdgeAuthSessionsTable get sessions =>
      DartEdgeAuthSessionsTable.withSchema(databaseSchema);

  DartEdgeAuthUsersTable get users =>
      DartEdgeAuthUsersTable.withSchema(databaseSchema);
}
