import 'package:json_schema/json_schema.dart';
import 'tables/account.g.dart';
import 'tables/passkey.g.dart';
import 'tables/session.g.dart';
import 'tables/user.g.dart';
import 'tables/verification.g.dart';
export 'tables/account.g.dart';
export 'tables/passkey.g.dart';
export 'tables/session.g.dart';
export 'tables/user.g.dart';
export 'tables/verification.g.dart';

final class DefaultSchema {
  const DefaultSchema({this.databaseSchema});

  const DefaultSchema._() : databaseSchema = null;

  final String? databaseSchema;

  static const instance = DefaultSchema._();

  static const schemaName = 'default';

  static const account = DartEdgeAuthAccountsTable.table;

  static const passkey = DartEdgeAuthPasskeysTable.table;

  static const session = DartEdgeAuthSessionsTable.table;

  static const user = DartEdgeAuthUsersTable.table;

  static const verification = DartEdgeAuthVerificationsTable.table;

  static const List<JsonSchema> schemas = <JsonSchema>[
    DartEdgeAuthAccountRow.jsonSchema,
    DartEdgeAuthAccountInsert.jsonSchema,
    DartEdgeAuthAccountUpdate.jsonSchema,
    DartEdgeAuthPasskeyRow.jsonSchema,
    DartEdgeAuthPasskeyInsert.jsonSchema,
    DartEdgeAuthPasskeyUpdate.jsonSchema,
    DartEdgeAuthSessionRow.jsonSchema,
    DartEdgeAuthSessionInsert.jsonSchema,
    DartEdgeAuthSessionUpdate.jsonSchema,
    DartEdgeAuthUserRow.jsonSchema,
    DartEdgeAuthUserInsert.jsonSchema,
    DartEdgeAuthUserUpdate.jsonSchema,
    DartEdgeAuthVerificationRow.jsonSchema,
    DartEdgeAuthVerificationInsert.jsonSchema,
    DartEdgeAuthVerificationUpdate.jsonSchema,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}

extension DefaultSchemaTables on DefaultSchema {
  DartEdgeAuthAccountsTable get account => DartEdgeAuthAccountsTable.withSchema(
    databaseSchema ?? DartEdgeAuthAccountsTable.table.schema,
  );

  DartEdgeAuthPasskeysTable get passkey => DartEdgeAuthPasskeysTable.withSchema(
    databaseSchema ?? DartEdgeAuthPasskeysTable.table.schema,
  );

  DartEdgeAuthSessionsTable get session => DartEdgeAuthSessionsTable.withSchema(
    databaseSchema ?? DartEdgeAuthSessionsTable.table.schema,
  );

  DartEdgeAuthUsersTable get user => DartEdgeAuthUsersTable.withSchema(
    databaseSchema ?? DartEdgeAuthUsersTable.table.schema,
  );

  DartEdgeAuthVerificationsTable get verification =>
      DartEdgeAuthVerificationsTable.withSchema(
        databaseSchema ?? DartEdgeAuthVerificationsTable.table.schema,
      );
}
