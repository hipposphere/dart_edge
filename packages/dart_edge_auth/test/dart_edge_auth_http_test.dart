import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('exposes readable auth route debug strings', () {
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    final route = auth.routes<TestServices>().first;
    final routes = auth.routes<TestServices>();
    final operationIds = {
      for (final mount in routes) mount.route.options.operationId,
    };
    final paths = {for (final mount in routes) mount.path};

    expect(
      auth.toString(),
      startsWith('DartEdgeAuth(basePath: /auth, routes: '),
    );
    expect(route.toString(), contains('DartEdgeAuthRoute<TestServices>('));
    expect(route.toString(), contains('operationId:'));
    expect(route.toString(), contains('/auth/'));
    expect(operationIds, contains('openapi_spec'));
    expect(operationIds, contains('delete_user_delete'));
    expect(paths, isNot(contains('/auth/health')));
  });

  test('registers OAuth routes when OAuth providers are configured', () {
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
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
          ),
        ],
      ),
    );
    addTearDown(auth.dispose);

    final routes = auth.routes<TestServices>();
    final operationIds = {
      for (final mount in routes) mount.route.options.operationId,
    };
    final paths = {for (final mount in routes) mount.path};

    expect(operationIds, contains('social_sign_in'));
    expect(operationIds, contains('oauth_callback'));
    expect(paths, contains('/auth/sign-in/social'));
    expect(paths, contains('/auth/callback/<provider>'));
  });

  test(
    'mounts better-auth routes and proxies status, body, and headers',
    () async {
      final app = DartEdge<TestServices>(services: TestServices.new);
      final auth = DartEdgeAuth(
        const DartEdgeAuthConfig(
          workerPoolSize: 4,
          secret: 'test-secret-key-that-is-at-least-32-characters-long',
          baseUrl: 'http://localhost:3000',
        ),
      );
      auth.mount(app);

      expect(
        app.routeRegistry.registrations.first.toString(),
        contains('RouteRegistration('),
      );
      expect(
        app.routeRegistry.registrations.first.toString(),
        contains('DartEdgeAuthRoute<TestServices>('),
      );

      final server = await app.listen(port: 0);
      final client = HttpClient();

      addTearDown(() async {
        client.close(force: true);
        await server.close();
        auth.dispose();
      });

      final baseUri = Uri.http('127.0.0.1:${server.port}');

      final signupRequest = await client.postUrl(
        baseUri.resolve('/auth/sign-up/email'),
      );
      signupRequest.headers.contentType = ContentType.json;
      signupRequest.headers.set('origin', 'http://localhost:3000');
      signupRequest.write(
        jsonEncode({
          'email': 'ada@example.com',
          'password': 'password123',
          'name': 'Ada Lovelace',
        }),
      );
      final signupResponse = await signupRequest.close();
      expect(signupResponse.statusCode, HttpStatus.ok);
      expect(
        signupResponse.headers.value(HttpHeaders.setCookieHeader),
        contains('better-auth.session-token='),
      );

      final signupJson =
          jsonDecode(await utf8.decoder.bind(signupResponse).join())
              as Map<String, Object?>;
      final token = signupJson['token'] as String;

      final sessionRequest = await client.getUrl(
        baseUri.resolve('/auth/get-session'),
      );
      sessionRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $token',
      );
      sessionRequest.headers.set('origin', 'http://localhost:3000');
      final sessionResponse = await sessionRequest.close();
      expect(sessionResponse.statusCode, HttpStatus.ok);
      final sessionJson =
          jsonDecode(await utf8.decoder.bind(sessionResponse).join())
              as Map<String, Object?>;
      final user = sessionJson['user'] as Map<String, Object?>;
      expect(user['email'], 'ada@example.com');

      final signOutRequest = await client.postUrl(
        baseUri.resolve('/auth/sign-out'),
      );
      signOutRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $token',
      );
      signOutRequest.headers.set('origin', 'http://localhost:3000');
      final signOutResponse = await signOutRequest.close();
      expect(signOutResponse.statusCode, HttpStatus.ok);
      expect(
        signOutResponse.headers.value(HttpHeaders.setCookieHeader),
        contains('Expires=Thu, 01 Jan 1970'),
      );
    },
  );

  test('mounts better-auth routes as native HTTP handlers', () async {
    final app = DartEdge<TestServices>(services: TestServices.new);
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    auth.mountNative(app);

    final document = app.buildOpenApiDocumentJson();
    final paths = document['paths']! as Map<String, Object?>;
    expect(paths.keys, contains('/auth/sign-up/email'));

    final server = await app.listen(port: 0);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');
    final signupRequest = await client.postUrl(
      baseUri.resolve('/auth/sign-up/email'),
    );
    signupRequest.headers.contentType = ContentType.json;
    signupRequest.headers.set('origin', 'http://localhost:3000');
    signupRequest.write(
      jsonEncode({
        'email': 'native@example.com',
        'password': 'password123',
        'name': 'Native User',
      }),
    );

    final signupResponse = await signupRequest.close();
    expect(signupResponse.statusCode, HttpStatus.ok);
    expect(
      signupResponse.headers.value(HttpHeaders.setCookieHeader),
      contains('better-auth.session-token='),
    );
  });

  test('mounts native better-auth routes below router prefixes', () async {
    final app = DartEdge<TestServices>(services: TestServices.new);
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    auth.mountNative(app.router('/api', tags: ['auth']));

    final document = app.buildOpenApiDocumentJson();
    final paths = document['paths']! as Map<String, Object?>;
    expect(paths.keys, contains('/api/auth/sign-up/email'));
    expect(paths.keys, isNot(contains('/auth/sign-up/email')));

    final server = await app.listen(port: 0);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');
    final signupRequest = await client.postUrl(
      baseUri.resolve('/api/auth/sign-up/email'),
    );
    signupRequest.headers.contentType = ContentType.json;
    signupRequest.headers.set('origin', 'http://localhost:3000');
    signupRequest.write(
      jsonEncode({
        'email': 'native-prefix@example.com',
        'password': 'password123',
        'name': 'Native Prefix User',
      }),
    );

    final signupResponse = await signupRequest.close();
    expect(signupResponse.statusCode, HttpStatus.ok);
    final signupJson =
        jsonDecode(await utf8.decoder.bind(signupResponse).join())
            as Map<String, Object?>;
    final token = signupJson['token'] as String;

    final sessionRequest = await client.getUrl(
      baseUri.resolve('/api/auth/get-session'),
    );
    sessionRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $token',
    );
    sessionRequest.headers.set('origin', 'http://localhost:3000');
    final sessionResponse = await sessionRequest.close();
    expect(sessionResponse.statusCode, HttpStatus.ok);
  });

  test('builds OpenAPI auth paths without duplicating the auth base path', () {
    final app = DartEdge<TestServices>(services: TestServices.new);
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    auth.mount(app.router('', tags: ['auth']));

    final document = app.buildOpenApiDocumentJson();
    final paths = document['paths']! as Map<String, Object?>;

    expect(paths.keys, contains('/auth/sign-in/email'));
    expect(paths.keys.where((path) => path.contains('/auth/auth/')), isEmpty);
  });

  test('auth guard resolves identity and protects a route', () async {
    final app = DartEdge<TestServices>(services: TestServices.new);
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        workerPoolSize: 4,
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    auth.mount(app);
    app
        .router('', guards: [DartEdgeAuthGuard<TestServices>(auth: auth)])
        .get<Map<String, Object?>>(
          '/me',
          handler: (ctx) => {
            'email': ctx.requireAuthIdentity.email,
            'userId': ctx.requireAuthIdentity.userId,
          },
        );

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');
    final signupRequest = await client.postUrl(
      baseUri.resolve('/auth/sign-up/email'),
    );
    signupRequest.headers.contentType = ContentType.json;
    signupRequest.headers.set('origin', 'http://localhost:3000');
    signupRequest.write(
      jsonEncode({
        'email': 'guard@example.com',
        'password': 'password123',
        'name': 'Guard User',
      }),
    );
    final signupResponse = await signupRequest.close();
    final signupJson =
        jsonDecode(await utf8.decoder.bind(signupResponse).join())
            as Map<String, Object?>;
    final token = signupJson['token'] as String;

    final unauthorizedResponse = await (await client.getUrl(
      baseUri.resolve('/me'),
    )).close();
    expect(unauthorizedResponse.statusCode, HttpStatus.unauthorized);

    final authorizedRequest = await client.getUrl(baseUri.resolve('/me'));
    authorizedRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $token',
    );
    final authorizedResponse = await authorizedRequest.close();
    expect(authorizedResponse.statusCode, HttpStatus.ok);

    final body =
        jsonDecode(await utf8.decoder.bind(authorizedResponse).join())
            as Map<String, Object?>;
    expect(body['email'], 'guard@example.com');
    expect(body['userId'], isA<String>());
  });
}

final class TestServices {
  const TestServices();
}
