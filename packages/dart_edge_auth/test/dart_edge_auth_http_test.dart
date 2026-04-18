import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_runtime/dart_edge_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('exposes readable auth route debug strings', () {
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
        secret: 'test-secret-key-that-is-at-least-32-characters-long',
        baseUrl: 'http://localhost:3000',
      ),
    );
    addTearDown(auth.dispose);

    final route = auth.routes<TestServices>().first;

    expect(
      auth.toString(),
      startsWith('DartEdgeAuth(basePath: /auth, routes: '),
    );
    expect(route.toString(), contains('DartEdgeAuthRoute<TestServices>('));
    expect(route.toString(), contains('operationId:'));
    expect(route.toString(), contains('/auth/'));
  });

  test(
    'mounts better-auth routes and proxies status, body, and headers',
    () async {
      final app = DartEdge<TestServices>(services: TestServices.new);
      final auth = DartEdgeAuth(
        const DartEdgeAuthConfig(
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

  test('builds OpenAPI auth paths without duplicating the auth base path', () {
    final app = DartEdge<TestServices>(services: TestServices.new);
    final auth = DartEdgeAuth(
      const DartEdgeAuthConfig(
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
}

final class TestServices {
  const TestServices();
}
