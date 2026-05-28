import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_better_auth/dart_edge_better_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';
import 'package:test/test.dart';

void main() {
  const secret = 'test-secret-key-that-is-at-least-32-characters-long';
  const baseUrl = 'http://localhost:3000';

  test('verifies Better Auth TypeScript password hashes', () async {
    final valid = await betterAuthVerifyPassword(
      password: 'password123',
      hash:
          'e9605d99e8bc6806172f9e22632cfd5a:'
          '88a3b3be19e1974ce9a764601983674bba671023f7306058d0368b06bb29a674'
          'ca5027d64fac5a80e8d22209088cfba90d13c9fa4a2c544d0e2bbbf0d8588c82',
    );
    expect(valid, isTrue);
  });

  test('trusted admin can bootstrap a PGlite account', () async {
    final endpoint = PgliteDatabase.temporary();
    final pool = endpoint.asPostgresPool();
    addTearDown(pool.close);

    await DartEdgeBetterAuthMigrator(pool: pool).migrateToLatest();
    final auth = DartEdgeBetterAuth.withPool(
      options: const BetterAuthOptions(secret: secret, baseUrl: baseUrl),
      pool: pool,
    );

    final created = await auth.trusted.admin.createUser(
      email: 'admin@example.com',
      password: 'password123',
      name: 'Admin User',
    );
    expect(created.user.role, 'admin');

    final signIn = await auth.api.signInEmail(
      email: 'admin@example.com',
      password: 'password123',
    );
    expect(signIn.user.id, created.user.id);

    final session = await auth.api.getSession(token: signIn.token);
    expect(session.user.email, 'admin@example.com');

    final users = await auth.trusted.admin.listUsers(limit: 10);
    expect(users.total, 1);
  });

  test('trusted admin can bootstrap a SQLite account', () async {
    final database = SqliteDatabase.inMemory();
    addTearDown(database.close);

    await DartEdgeBetterAuthMigrator(pool: database).migrateToLatest();
    final auth = DartEdgeBetterAuth.withPool(
      options: const BetterAuthOptions(secret: secret, baseUrl: baseUrl),
      pool: database,
    );

    final created = await auth.trusted.admin.createUser(
      email: 'sqlite-admin@example.com',
      password: 'password123',
      name: 'SQLite Admin',
    );
    expect(created.user.email, 'sqlite-admin@example.com');

    final signIn = await auth.api.signInEmail(
      email: 'sqlite-admin@example.com',
      password: 'password123',
    );
    expect(signIn.user.id, created.user.id);
  });

  test('admin api requires an admin session', () async {
    final endpoint = PgliteDatabase.temporary();
    final pool = endpoint.asPostgresPool();
    addTearDown(pool.close);

    await DartEdgeBetterAuthMigrator(pool: pool).migrateToLatest();
    final auth = DartEdgeBetterAuth.withPool(
      options: const BetterAuthOptions(secret: secret, baseUrl: baseUrl),
      pool: pool,
    );

    final admin = await auth.trusted.admin.createUser(
      email: 'http-admin@example.com',
      password: 'password123',
      name: 'HTTP Admin',
    );
    final member = await auth.trusted.createUser(
      email: 'http-member@example.com',
      password: 'password123',
      name: 'HTTP Member',
      role: 'member',
    );

    final adminSignIn = await auth.api.signInEmail(
      email: 'http-admin@example.com',
      password: 'password123',
    );
    final memberSignIn = await auth.api.signInEmail(
      email: 'http-member@example.com',
      password: 'password123',
    );

    await expectLater(
      auth.api.admin.createUser(
        token: memberSignIn.token,
        email: 'blocked@example.com',
        password: 'password123',
        name: 'Blocked',
      ),
      throwsA(
        isA<BetterAuthApiException>().having(
          (error) => error.status,
          'status',
          403,
        ),
      ),
    );

    final created = await auth.api.admin.createUser(
      token: adminSignIn.token,
      email: 'created-by-admin@example.com',
      password: 'password123',
      name: 'Created By Admin',
      role: 'member',
    );
    expect(created.user.role, 'member');

    final promoted = await auth.api
        .withBearerToken(adminSignIn.token)
        .admin
        .setRole(userId: member.user.id, role: 'admin');
    expect(promoted.user.role, 'admin');

    final users = await auth.api.admin.listUsers(token: adminSignIn.token);
    expect(users.users.map((user) => user.id), contains(admin.user.id));
    expect(users.users.map((user) => user.email), contains(created.user.email));

    final fetchedMember = await auth.api.admin.getUser(
      token: adminSignIn.token,
      userId: member.user.id,
    );
    expect(fetchedMember.user.email, member.user.email);

    final memberSessions = await auth.api.admin.listUserSessions(
      token: adminSignIn.token,
      userId: member.user.id,
    );
    expect(memberSessions.sessions.map((session) => session.token), [
      memberSignIn.token,
    ]);

    final adminPermissions = await auth.api.admin.hasPermission(
      token: adminSignIn.token,
      permissions: const {
        'user': ['create', 'list', 'get', 'update'],
        'session': ['list', 'revoke'],
      },
    );
    expect(adminPermissions.success, isTrue);

    final memberPermissions = await auth.api.admin.hasPermission(
      userId: created.user.id,
      permissions: const {
        'user': ['create'],
      },
    );
    expect(memberPermissions.success, isFalse);

    final impersonated = await auth.api.admin.impersonateUser(
      token: adminSignIn.token,
      userId: created.user.id,
    );
    expect(impersonated.user.id, created.user.id);
    expect(impersonated.session.userId, created.user.id);
    expect(impersonated.session.impersonatedBy, admin.user.id);
    expect(
      impersonated.session.expiresAt.difference(DateTime.now().toUtc()),
      lessThanOrEqualTo(const Duration(hours: 1)),
    );
    final impersonatedSession = await auth.api.getSession(
      token: impersonated.session.token,
    );
    expect(impersonatedSession.session.impersonatedBy, admin.user.id);

    final restoredAdmin = await auth.api.admin.stopImpersonating(
      token: impersonated.session.token,
      adminSessionToken: adminSignIn.token,
    );
    expect(restoredAdmin.user.id, admin.user.id);
    expect(restoredAdmin.session.token, adminSignIn.token);
    expect(restoredAdmin.session.impersonatedBy, isNull);
    expect(
      await auth.api.tryGetSession(token: impersonated.session.token),
      isNull,
    );

    await expectLater(
      auth.api.admin.impersonateUser(
        token: adminSignIn.token,
        userId: admin.user.id,
      ),
      throwsA(
        isA<BetterAuthApiException>()
            .having((error) => error.status, 'status', 403)
            .having(
              (error) => error.code,
              'code',
              'YOU_CANNOT_IMPERSONATE_ADMINS',
            ),
      ),
    );

    final updated = await auth.api.admin.updateUser(
      token: adminSignIn.token,
      userId: created.user.id,
      name: 'Updated User',
      email: 'updated-by-admin@example.com',
    );
    expect(updated.user.name, 'Updated User');
    expect(updated.user.email, 'updated-by-admin@example.com');

    final banned = await auth.api.admin.banUser(
      token: adminSignIn.token,
      userId: created.user.id,
      banReason: 'test',
    );
    expect(banned.user.banned, isTrue);
    expect(banned.user.banReason, 'test');

    final unbanned = await auth.api.admin.unbanUser(
      token: adminSignIn.token,
      userId: created.user.id,
    );
    expect(unbanned.user.banned, isFalse);

    await auth.api.admin.setUserPassword(
      token: adminSignIn.token,
      userId: created.user.id,
      password: 'new-password123',
    );
    final changedPasswordSignIn = await auth.api.signInEmail(
      email: 'updated-by-admin@example.com',
      password: 'new-password123',
    );
    expect(changedPasswordSignIn.user.id, created.user.id);

    await auth.api.admin.revokeUserSession(
      token: adminSignIn.token,
      sessionToken: changedPasswordSignIn.token,
    );
    expect(
      await auth.api.tryGetSession(token: changedPasswordSignIn.token),
      isNull,
    );

    final anotherSession = await auth.api.signInEmail(
      email: 'updated-by-admin@example.com',
      password: 'new-password123',
    );
    await auth.api.admin.revokeUserSessions(
      token: adminSignIn.token,
      userId: created.user.id,
    );
    expect(await auth.api.tryGetSession(token: anotherSession.token), isNull);

    await auth.api.admin.removeUser(
      token: adminSignIn.token,
      userId: created.user.id,
    );
    await expectLater(
      auth.api.signInEmail(
        email: 'updated-by-admin@example.com',
        password: 'new-password123',
      ),
      throwsA(isA<BetterAuthApiException>()),
    );
  });

  test(
    'signs in with credentials created by TypeScript Better Auth on PGlite',
    () async {
      final fixture = Directory('test/node_better_auth_interop');
      if (!fixture.existsSync()) {
        markTestSkipped('Node Better Auth interop fixture is missing.');
        return;
      }
      if (!Directory('${fixture.path}/node_modules').existsSync()) {
        markTestSkipped(
          'Run `npm install` in ${fixture.path} to enable this interop test.',
        );
        return;
      }

      const email = 'typescript-better-auth@example.com';
      const password = 'password123';
      const name = 'TypeScript Better Auth User';

      final endpoint = PgliteDatabase.temporary();
      addTearDown(endpoint.close);

      final seed = await Process.run('node', [
        'seed-user.mjs',
        jsonEncode({
          'connectionString': endpoint.connectionString,
          'secret': secret,
          'baseUrl': baseUrl,
          'email': email,
          'password': password,
          'name': name,
        }),
      ], workingDirectory: fixture.path);
      if (seed.exitCode != 0) {
        fail(
          'TypeScript Better Auth seed failed with exit code '
          '${seed.exitCode}.\nSTDOUT:\n${seed.stdout}\nSTDERR:\n${seed.stderr}',
        );
      }

      final pool = PostgresPool.withUrl(
        endpoint.connectionString,
        maxSessions: 1,
      );
      final auth = DartEdgeBetterAuth.withPool(
        options: const BetterAuthOptions(secret: secret, baseUrl: baseUrl),
        pool: pool,
      );
      addTearDown(pool.close);

      final signIn = await auth.api.signInEmail(
        email: email,
        password: password,
      );

      expect(signIn.user.email, email);
      expect(signIn.user.name, name);
      expect(signIn.token, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'TypeScript Better Auth signs in with trusted-created credentials',
    () async {
      final fixture = Directory('test/node_better_auth_interop');
      if (!fixture.existsSync()) {
        markTestSkipped('Node Better Auth interop fixture is missing.');
        return;
      }
      if (!Directory('${fixture.path}/node_modules').existsSync()) {
        markTestSkipped(
          'Run `npm install` in ${fixture.path} to enable this interop test.',
        );
        return;
      }

      const email = 'trusted-dart-better-auth@example.com';
      const password = 'password123';

      final endpoint = PgliteDatabase.temporary();
      final pool = PostgresPool.withUrl(
        endpoint.connectionString,
        maxSessions: 1,
      );
      addTearDown(() async {
        await pool.close();
        await endpoint.close();
      });

      await DartEdgeBetterAuthMigrator(pool: pool).migrateToLatest();
      final auth = DartEdgeBetterAuth.withPool(
        options: const BetterAuthOptions(secret: secret, baseUrl: baseUrl),
        pool: pool,
      );

      final created = await auth.trusted.createUser(
        email: email,
        password: password,
        name: 'Trusted Dart Better Auth User',
      );
      await pool.close();

      final signIn = await Process.run('node', [
        'sign-in-user.mjs',
        jsonEncode({
          'connectionString': endpoint.connectionString,
          'secret': secret,
          'baseUrl': baseUrl,
          'email': email,
          'password': password,
        }),
      ], workingDirectory: fixture.path);
      if (signIn.exitCode != 0) {
        fail(
          'TypeScript Better Auth sign-in failed with exit code '
          '${signIn.exitCode}.\nSTDOUT:\n${signIn.stdout}\n'
          'STDERR:\n${signIn.stderr}',
        );
      }

      final lines = LineSplitter.split(
        (signIn.stdout as String).trim(),
      ).where((line) => line.trim().isNotEmpty).toList();
      final json = jsonDecode(lines.last) as Map<String, Object?>;
      expect(json['email'], email);
      expect(json['userId'], created.user.id);
      expect(json['hasToken'], isTrue);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
