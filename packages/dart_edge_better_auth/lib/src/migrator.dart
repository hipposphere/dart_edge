import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';

final class DartEdgeBetterAuthMigrator {
  DartEdgeBetterAuthMigrator({required SqlPool pool, String? postgresSchema})
    : _migrator = DartEdgeSqlMigrator(
        pool: pool,
        migrations: betterAuthMigrations(postgresSchema: postgresSchema),
      );

  final DartEdgeSqlMigrator _migrator;

  Future<int> migrateToLatest() => _migrator.migrateToLatest();

  Future<SqlMigrationStatus> status() => _migrator.status();
}

List<SqlMigration> betterAuthMigrations({String? postgresSchema}) {
  final schemaPrefix = postgresSchema == null ? '' : '"$postgresSchema".';
  return [
    SqlMigration(
      version: '0001',
      name: 'create_better_auth_tables',
      up: SqlMigrationPlan(
        byDialect: {
          SqlDialect.postgres: [
            if (postgresSchema != null)
              sql('CREATE SCHEMA IF NOT EXISTS "$postgresSchema"'),
            sql('''
CREATE TABLE IF NOT EXISTS $schemaPrefix"user" (
  id text NOT NULL PRIMARY KEY,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  "emailVerified" boolean NOT NULL,
  image text,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  role text,
  banned boolean,
  "banReason" text,
  "banExpires" timestamptz,
  "phoneNumber" text UNIQUE,
  "phoneNumberVerified" boolean
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS $schemaPrefix"session" (
  id text NOT NULL PRIMARY KEY,
  "expiresAt" timestamptz NOT NULL,
  token text NOT NULL UNIQUE,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  "ipAddress" text,
  "userAgent" text,
  "userId" text NOT NULL REFERENCES $schemaPrefix"user" (id) ON DELETE CASCADE,
  "impersonatedBy" text
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS $schemaPrefix"account" (
  id text NOT NULL PRIMARY KEY,
  "accountId" text NOT NULL,
  "providerId" text NOT NULL,
  "userId" text NOT NULL REFERENCES $schemaPrefix"user" (id) ON DELETE CASCADE,
  "accessToken" text,
  "refreshToken" text,
  "idToken" text,
  "accessTokenExpiresAt" timestamptz,
  "refreshTokenExpiresAt" timestamptz,
  scope text,
  password text,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS $schemaPrefix"verification" (
  id text NOT NULL PRIMARY KEY,
  identifier text NOT NULL,
  value text NOT NULL,
  "expiresAt" timestamptz NOT NULL,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS $schemaPrefix"passkey" (
  id text NOT NULL PRIMARY KEY,
  name text,
  "publicKey" text NOT NULL,
  "userId" text NOT NULL REFERENCES $schemaPrefix"user" (id) ON DELETE CASCADE,
  "credentialID" text NOT NULL,
  counter integer NOT NULL,
  "deviceType" text NOT NULL,
  "backedUp" boolean NOT NULL,
  transports text,
  "createdAt" timestamptz,
  aaguid text
)
'''),
          ],
          SqlDialect.sqlite: [
            sql('''
CREATE TABLE IF NOT EXISTS "user" (
  id text NOT NULL PRIMARY KEY,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  "emailVerified" integer NOT NULL,
  image text,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL,
  role text,
  banned integer,
  "banReason" text,
  "banExpires" text,
  "phoneNumber" text UNIQUE,
  "phoneNumberVerified" integer
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS "session" (
  id text NOT NULL PRIMARY KEY,
  "expiresAt" text NOT NULL,
  token text NOT NULL UNIQUE,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL,
  "ipAddress" text,
  "userAgent" text,
  "userId" text NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
  "impersonatedBy" text
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS "account" (
  id text NOT NULL PRIMARY KEY,
  "accountId" text NOT NULL,
  "providerId" text NOT NULL,
  "userId" text NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
  "accessToken" text,
  "refreshToken" text,
  "idToken" text,
  "accessTokenExpiresAt" text,
  "refreshTokenExpiresAt" text,
  scope text,
  password text,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS "verification" (
  id text NOT NULL PRIMARY KEY,
  identifier text NOT NULL,
  value text NOT NULL,
  "expiresAt" text NOT NULL,
  "createdAt" text NOT NULL,
  "updatedAt" text NOT NULL
)
'''),
            sql('''
CREATE TABLE IF NOT EXISTS "passkey" (
  id text NOT NULL PRIMARY KEY,
  name text,
  "publicKey" text NOT NULL,
  "userId" text NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
  "credentialID" text NOT NULL,
  counter integer NOT NULL,
  "deviceType" text NOT NULL,
  "backedUp" integer NOT NULL,
  transports text,
  "createdAt" text,
  aaguid text
)
'''),
          ],
        },
      ),
    ),
  ];
}
