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

  static const account = BetterAuthAccountsTable.table;

  static const passkey = BetterAuthPasskeysTable.table;

  static const session = BetterAuthSessionsTable.table;

  static const user = BetterAuthUsersTable.table;

  static const verification = BetterAuthVerificationsTable.table;

  static const List<JsonSchema> schemas = <JsonSchema>[
    BetterAuthAccountRow.jsonSchema,
    BetterAuthAccountInsert.jsonSchema,
    BetterAuthAccountUpdate.jsonSchema,
    BetterAuthPasskeyRow.jsonSchema,
    BetterAuthPasskeyInsert.jsonSchema,
    BetterAuthPasskeyUpdate.jsonSchema,
    BetterAuthSessionRow.jsonSchema,
    BetterAuthSessionInsert.jsonSchema,
    BetterAuthSessionUpdate.jsonSchema,
    BetterAuthUserRow.jsonSchema,
    BetterAuthUserInsert.jsonSchema,
    BetterAuthUserUpdate.jsonSchema,
    BetterAuthVerificationRow.jsonSchema,
    BetterAuthVerificationInsert.jsonSchema,
    BetterAuthVerificationUpdate.jsonSchema,
  ];

  static const JsonSchemaRegistry jsonSchemas = JsonSchemaRegistry(
    schemas: schemas,
  );
}

extension DefaultSchemaTables on DefaultSchema {
  BetterAuthAccountsTable get account => BetterAuthAccountsTable.withSchema(
    databaseSchema ?? BetterAuthAccountsTable.table.schema,
  );

  BetterAuthPasskeysTable get passkey => BetterAuthPasskeysTable.withSchema(
    databaseSchema ?? BetterAuthPasskeysTable.table.schema,
  );

  BetterAuthSessionsTable get session => BetterAuthSessionsTable.withSchema(
    databaseSchema ?? BetterAuthSessionsTable.table.schema,
  );

  BetterAuthUsersTable get user => BetterAuthUsersTable.withSchema(
    databaseSchema ?? BetterAuthUsersTable.table.schema,
  );

  BetterAuthVerificationsTable get verification =>
      BetterAuthVerificationsTable.withSchema(
        databaseSchema ?? BetterAuthVerificationsTable.table.schema,
      );
}
