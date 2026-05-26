import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';
import 'package:test/test.dart';

void main() {
  test('supports direct sign-up and session calls without HTTP', () async {
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    final signup = await auth.api.signUpEmail(
      email: 'ada@example.com',
      password: 'password123',
      name: 'Ada Lovelace',
    );
    final token = signup.token!;

    expect(signup.user.email, 'ada@example.com');
    expect(
      signup.response.header('set-cookie'),
      contains('better-auth.session-token='),
    );

    final session = await auth.api.getSession(
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    );
    expect(session.user.email, 'ada@example.com');
    expect(session.session.userId, signup.user.id);

    final anonymousSession = await auth.api.tryGetSession();
    expect(anonymousSession, isNull);

    final signOut = await auth.api.withBearerToken(token).signOut();
    expect(signOut.success, isTrue);
    expect(
      signOut.response.header('set-cookie'),
      contains('Expires=Thu, 01 Jan 1970'),
    );
  });

  test('shares one sqlite in-memory database with dart_edge_sql', () async {
    final database = SqliteDatabase.inMemory();
    final auth = DartEdgeAuth(
      DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
        database: DartEdgeAuthDatabase.fromDatabase(
          database,
          manageMigrations: true,
        ),
      ),
    );

    addTearDown(() async {
      auth.dispose();
      await database.close();
    });

    final signup = await auth.api.signUpEmail(
      email: 'sqlite@example.com',
      password: 'password123',
      name: 'SQLite User',
    );
    final token = signup.token!;

    expect(signup.user.email, 'sqlite@example.com');

    final session = await auth.api.withBearerToken(token).getSession();
    expect(session.user.email, 'sqlite@example.com');

    final users = await database.execute(
      sql(
        'SELECT email FROM "user" WHERE email = ?',
        parameters: ['sqlite@example.com'],
      ),
    );
    expect(users.rows.single['email'], 'sqlite@example.com');

    final typedUsers = await database.typed
        .from(DartEdgeAuthSchema.users)
        .selectAll()
        .where(DartEdgeAuthUsersTable.email.equals('sqlite@example.com'))
        .execute();
    expect(typedUsers.single.email, 'sqlite@example.com');
  });

  test('trusted admin works with a shared pglite auth schema', () async {
    final database = PgliteDatabase.temporary().asPostgresPool();
    await _runPostgresAuthMigrations(database);

    final auth = DartEdgeAuth(
      DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
        database: DartEdgeAuthDatabase.fromPostgresPool(
          database,
          schema: 'auth',
          manageMigrations: false,
        ),
      ),
    );

    addTearDown(() async {
      auth.dispose();
      await database.close();
    });

    final created = await auth.trustedAdmin.createUser(
      email: 'pglite-trusted@example.com',
      password: 'password123',
      name: 'PGlite Trusted User',
      role: 'admin',
    );
    expect(created.user.email, 'pglite-trusted@example.com');
    expect(created.user.role, 'admin');

    final signIn = await auth.api.signInEmail(
      email: 'pglite-trusted@example.com',
      password: 'password123',
    );
    expect(signIn.user!.id, created.user.id);

    final users = await database.execute(
      sql(
        'SELECT email FROM auth."user" WHERE email = @email',
        parameters: {'email': 'pglite-trusted@example.com'},
      ),
    );
    expect(users.rows.single['email'], 'pglite-trusted@example.com');

    final accounts = await database.execute(
      sql(
        'SELECT password FROM auth."account" WHERE "userId" = @userId',
        parameters: {'userId': created.user.id},
      ),
    );
    expect(accounts.rows.single['password'], isA<String>());

    final listed = await auth.trustedAdmin.listUsers(limit: 10);
    expect(listed.total, 1);
    expect(listed.users.single.email, 'pglite-trusted@example.com');
  });

  test('can disable shared sqlite migration management', () async {
    final database = SqliteDatabase.inMemory();
    await _runSqliteAuthMigrations(database);

    final auth = DartEdgeAuth(
      DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
        database: DartEdgeAuthDatabase.fromDatabase(
          database,
          manageMigrations: false,
        ),
      ),
    );

    addTearDown(() async {
      auth.dispose();
      await database.close();
    });

    final signup = await auth.api.signUpEmail(
      email: 'manual-migration@example.com',
      password: 'password123',
      name: 'Manual Migration User',
    );

    expect(signup.user.email, 'manual-migration@example.com');

    final users = await database.execute(
      sql(
        'SELECT email FROM "user" WHERE email = ?',
        parameters: ['manual-migration@example.com'],
      ),
    );
    expect(users.rows.single['email'], 'manual-migration@example.com');
  });

  test('throws a typed exception for failed direct auth calls', () async {
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    await auth.api.signUpEmail(
      email: 'duplicate@example.com',
      password: 'password123',
      name: 'Duplicate User',
    );

    await expectLater(
      auth.api.signUpEmail(
        email: 'duplicate@example.com',
        password: 'password123',
        name: 'Duplicate User',
      ),
      throwsA(
        isA<DartEdgeAuthApiException>()
            .having((error) => error.status, 'status', 409)
            .having(
              (error) => error.message,
              'message',
              contains('already exists'),
            ),
      ),
    );
  });

  test(
    'explains when an admin operation is called without admin enabled',
    () async {
      final auth = DartEdgeAuth(
        const DartEdgeAuthConfig(
          workerPoolSize: 4,
          secret: 'test-secret-key-that-is-at-least-32-characters-long',
          baseUrl: 'http://localhost:3000',
        ),
      );
      addTearDown(auth.dispose);

      await expectLater(
        auth.api.admin.createUser(
          email: 'grace@example.com',
          password: 'password123',
          name: 'Grace Hopper',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Required Better Auth plugin: "admin"'),
          ),
        ),
      );
    },
  );

  test('supports trusted admin calls without a session token', () async {
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    final created = await auth.trustedAdmin.createUser(
      email: 'trusted@example.com',
      password: 'password123',
      name: 'Trusted User',
      role: 'member',
    );
    expect(created.user.email, 'trusted@example.com');
    expect(created.user.role, 'member');

    final signIn = await auth.api.signInEmail(
      email: 'trusted@example.com',
      password: 'password123',
    );
    expect(signIn.user!.id, created.user.id);

    final promoted = await auth.trustedAdmin.setRole(
      userId: created.user.id,
      role: 'admin',
    );
    expect(promoted.user.role, 'admin');

    final listed = await auth.trustedAdmin.listUsers(limit: 10);
    expect(listed.total, 1);
    expect(listed.users.single.email, 'trusted@example.com');
  });

  test('enables direct admin api calls when configured', () async {
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
        admin: DartEdgeAuthAdminConfig(),
      ),
    );
    addTearDown(auth.dispose);

    expect(
      auth.routes<void>().any(
        (route) => route.toString().contains('admin_create_user'),
      ),
      isTrue,
    );

    final signup = await auth.api.signUpEmail(
      email: 'admin@example.com',
      password: 'password123',
      name: 'Admin User',
    );
    final adminToken = signup.token!;

    final promote = await auth.api
        .withBearerToken(adminToken)
        .updateUser(role: 'admin');
    expect(promote.status, isTrue);

    final admin = auth.api.withBearerToken(adminToken).admin;
    final created = await admin.createUser(
      email: 'grace@example.com',
      password: 'password123',
      name: 'Grace Hopper',
      role: 'member',
    );
    expect(created.user.email, 'grace@example.com');
    expect(created.user.role, 'member');

    final listed = await admin.listUsers(limit: 10);
    final emails = listed.users.map((user) => user.email);
    expect(
      emails,
      containsAll(<Object?>['admin@example.com', 'grace@example.com']),
    );
  });
}

Future<void> _runSqliteAuthMigrations(SqliteDatabase database) async {
  final migrationSql = File(
    'rust/vendor/better-auth-diesel-sqlite/migrations/'
    '00000000000000_create_auth_tables/up.sql',
  ).readAsStringSync();

  for (final statement
      in migrationSql
          .split(';')
          .map((statement) => statement.trim())
          .where((statement) => statement.isNotEmpty)) {
    await database.execute(sql(statement));
  }
}

Future<void> _runPostgresAuthMigrations(PostgresPool database) async {
  const migrationSql = '''
CREATE SCHEMA IF NOT EXISTS auth;
SET search_path TO auth;

create table "user" ("id" text not null primary key, "name" text not null, "email" text not null unique, "emailVerified" boolean not null, "image" text, "createdAt" timestamptz  not null, "updatedAt" timestamptz  not null, "role" text, "banned" boolean, "banReason" text, "banExpires" timestamptz, "phoneNumber" text unique, "phoneNumberVerified" boolean);

create table "session" ("id" text not null primary key, "expiresAt" timestamptz not null, "token" text not null unique, "createdAt" timestamptz  not null, "updatedAt" timestamptz not null, "ipAddress" text, "userAgent" text, "userId" text not null references "user" ("id") on delete cascade, "impersonatedBy" text);

create table "account" ("id" text not null primary key, "accountId" text not null, "providerId" text not null, "userId" text not null references "user" ("id") on delete cascade, "accessToken" text, "refreshToken" text, "idToken" text, "accessTokenExpiresAt" timestamptz, "refreshTokenExpiresAt" timestamptz, "scope" text, "password" text, "createdAt" timestamptz not null, "updatedAt" timestamptz not null);

create table "verification" ("id" text not null primary key, "identifier" text not null, "value" text not null, "expiresAt" timestamptz not null, "createdAt" timestamptz  not null, "updatedAt" timestamptz  not null);

create table "passkey" ("id" text not null primary key, "name" text, "publicKey" text not null, "userId" text not null references "user" ("id") on delete cascade, "credentialID" text not null, "counter" integer not null, "deviceType" text not null, "backedUp" boolean not null, "transports" text, "createdAt" timestamptz, "aaguid" text);

SET search_path TO public;
''';

  for (final statement
      in migrationSql
          .split(';')
          .map((statement) => statement.trim())
          .where((statement) => statement.isNotEmpty)) {
    await database.execute(sql(statement));
  }
}
