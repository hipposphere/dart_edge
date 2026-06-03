import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:test/test.dart';

void main() {
  test('serializes native postgres auth database config', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.postgres(
        connectionString: 'postgresql://postgres:postgres@localhost:5432/app',
      ),
    );

    expect(config.toJson()['database'], {
      'kind': 'postgres',
      'connectionString': 'postgresql://postgres:postgres@localhost:5432/app',
    });
  });

  test('disables sqlite migration management by default', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.sqlite(path: 'auth.db'),
    );

    expect(config.toJson()['database'], {
      'kind': 'sqlite',
      'path': 'auth.db',
      'inMemory': false,
      'manageMigrations': false,
    });
  });

  test('serializes sqlite migration management config', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.sqlite(
        path: 'auth.db',
        manageMigrations: true,
      ),
    );

    expect(config.toJson()['database'], {
      'kind': 'sqlite',
      'path': 'auth.db',
      'inMemory': false,
      'manageMigrations': true,
    });
  });

  test('serializes admin plugin config', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      admin: DartEdgeAuthAdminConfig(
        adminRole: 'superadmin',
        defaultUserRole: 'member',
        allowBanAdmin: true,
        defaultPageLimit: 50,
        maxPageLimit: 250,
      ),
    );

    expect(config.toJson()['admin'], {
      'adminRole': 'superadmin',
      'defaultUserRole': 'member',
      'allowBanAdmin': true,
      'defaultPageLimit': 50,
      'maxPageLimit': 250,
    });
  });

  test('serializes rate-limit config', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      enableRateLimit: false,
    );

    expect(config.toJson()['enableRateLimit'], false);
  });

  test('serializes OAuth provider config', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      oauthProviders: [
        DartEdgeAuthOAuthProviderConfig(
          providerId: 'uka',
          clientId: 'client-id',
          clientSecret: 'client-secret',
          authorizationUrl: 'https://idp.example.test/oauth/authorize',
          tokenUrl: 'https://idp.example.test/oauth/token',
          userInfoUrl: 'https://idp.example.test/oauth/userinfo',
          scopes: ['openid', 'email'],
        ),
      ],
    );

    expect(config.toJson()['oauthProviders'], [
      {
        'providerId': 'uka',
        'clientId': 'client-id',
        'clientSecret': 'client-secret',
        'authorizationUrl': 'https://idp.example.test/oauth/authorize',
        'tokenUrl': 'https://idp.example.test/oauth/token',
        'userInfoUrl': 'https://idp.example.test/oauth/userinfo',
        'scopes': ['openid', 'email'],
      },
    ]);
  });

  test('serializes OAuth provider config without a client secret', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      oauthProviders: [
        DartEdgeAuthOAuthProviderConfig(
          providerId: 'uka',
          clientId: 'client-id',
          authorizationUrl: 'https://idp.example.test/oauth/authorize',
          tokenUrl: 'https://idp.example.test/oauth/token',
          userInfoUrl: 'https://idp.example.test/oauth/userinfo',
        ),
      ],
    );

    expect(config.toJson()['oauthProviders'], [
      {
        'providerId': 'uka',
        'clientId': 'client-id',
        'authorizationUrl': 'https://idp.example.test/oauth/authorize',
        'tokenUrl': 'https://idp.example.test/oauth/token',
        'userInfoUrl': 'https://idp.example.test/oauth/userinfo',
        'scopes': ['openid', 'email', 'profile'],
      },
    ]);
  });

  test('serializes OAuth provider config without a user info endpoint', () {
    const config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      oauthProviders: [
        DartEdgeAuthOAuthProviderConfig(
          providerId: 'uka',
          clientId: 'client-id',
          authorizationUrl: 'https://idp.example.test/oauth/authorize',
          tokenUrl: 'https://idp.example.test/oauth/token',
        ),
      ],
    );

    expect(config.toJson()['oauthProviders'], [
      {
        'providerId': 'uka',
        'clientId': 'client-id',
        'authorizationUrl': 'https://idp.example.test/oauth/authorize',
        'tokenUrl': 'https://idp.example.test/oauth/token',
        'scopes': ['openid', 'email', 'profile'],
      },
    ]);
  });

  test('derives native sqlite auth database config from a sqlite database', () {
    final database = SqliteDatabase.inMemory();
    addTearDown(database.close);

    final config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.fromDatabase(
        database,
        manageMigrations: false,
      ),
    );

    expect(config.toJson()['database'], {
      'kind': 'shared',
      'dialect': 'sqlite',
      'manageMigrations': false,
    });
  });

  test('serializes shared postgres auth schema config', () {
    final config = DartEdgeAuthConfig(
      workerPoolSize: 4,
      secret: 'test-secret-key-that-is-at-least-32-characters-long',
      baseUrl: 'http://localhost:3000',
      database: DartEdgeAuthDatabase.fromDatabase(
        const _FakeSqlPool(SqlDialect.postgres),
        schema: 'auth',
      ),
    );

    expect(config.toJson()['database'], {
      'kind': 'shared',
      'dialect': 'postgres',
      'schema': 'auth',
      'manageMigrations': false,
    });
  });

  test('exposes auth schemas with stable schema ids and refs', () {
    expect(DartEdgeAuthUser.schemaId, 'DartEdgeAuthUser');
    expect(DartEdgeAuthUser.schemaRef.toJson(), {
      r'$ref': '#/components/schemas/DartEdgeAuthUser',
    });
    expect(DartEdgeAuthUser.jsonSchema.id, DartEdgeAuthUser.schemaId);

    expect(DartEdgeAuthSignUpResult.schemaId, 'DartEdgeAuthSignUpResult');
    expect(DartEdgeAuthSignUpResult.schemaRef.toJson(), {
      r'$ref': '#/components/schemas/DartEdgeAuthSignUpResult',
    });
    expect(
      DartEdgeAuthSchema.jsonSchemas
          .schemaFor(DartEdgeAuthSignUpResult.schemaId)
          ?.id,
      DartEdgeAuthSignUpResult.schemaId,
    );
    expect(
      DartEdgeAuthSchema.schemas.map((schema) => schema.id),
      containsAll(<String>[
        DartEdgeAuthUser.schemaId,
        DartEdgeAuthSession.schemaId,
        DartEdgeAuthSignUpResult.schemaId,
        DartEdgeAuthPermissionResult.schemaId,
      ]),
    );
  });

  test('exposes generated auth tables with dynamic database schema', () {
    const defaultTables = DartEdgeAuthSchema();
    const authTables = DartEdgeAuthSchema(databaseSchema: 'auth');

    expect(DartEdgeAuthSchema.users.qualifiedName, 'user');
    expect(defaultTables.users.qualifiedName, 'user');
    expect(authTables.users.qualifiedName, 'auth.user');
    expect(authTables.sessions.userId.qualifiedName, 'auth.session.userId');
    expect(authTables.users.emailVerified, isA<SqlColumn<bool>>());
    expect(authTables.users.banExpires, isA<SqlColumn<DateTime>>());
    expect(authTables.sessions.expiresAt, isA<SqlColumn<DateTime>>());
    expect(authTables.sessions.expiresAt.databaseType, 'timestamptz');
  });
}

final class _FakeSqlPool implements SqlPool {
  const _FakeSqlPool(this.dialect);

  @override
  final SqlDialect dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    throw UnsupportedError('Fake pool only supports config serialization.');
  }

  @override
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action) {
    throw UnsupportedError('Fake pool only supports config serialization.');
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) {
    throw UnsupportedError('Fake pool only supports config serialization.');
  }

  @override
  Future<void> close() async {}
}
