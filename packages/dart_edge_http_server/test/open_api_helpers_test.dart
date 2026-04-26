import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:test/test.dart';

void main() {
  test('serves the generated OpenAPI document and Swagger UI', () async {
    final app = DartEdge<void>(
      services: () {},
      openApiDocument: OpenApiDocument(
        title: 'Example API',
        version: '2026.04.17',
      ),
    );
    app.get('/health', handler: (_) => const {'status': 'ok'});
    OpenApiHelpers.mountJson(app, path: '/openapi.json');
    OpenApiHelpers.mountSwaggerUi(
      app,
      path: '/docs',
      specPath: '/openapi.json',
    );

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');

    final openApiResponse = await (await client.getUrl(
      baseUri.resolve('/openapi.json'),
    )).close();
    expect(openApiResponse.statusCode, HttpStatus.ok);
    expect(openApiResponse.headers.contentType?.mimeType, 'application/json');

    final openApiJson =
        jsonDecode(await utf8.decoder.bind(openApiResponse).join())
            as Map<String, Object?>;
    expect(openApiJson['openapi'], '3.1.0');
    expect(openApiJson['info'], containsPair('title', 'Example API'));
    expect(openApiJson['paths'], contains('/health'));

    final docsResponse = await (await client.getUrl(
      baseUri.resolve('/docs'),
    )).close();
    expect(docsResponse.statusCode, HttpStatus.ok);
    expect(docsResponse.headers.contentType?.mimeType, 'text/html');

    final html = await utf8.decoder.bind(docsResponse).join();
    expect(html, contains('SwaggerUIBundle'));
    expect(html, contains('/openapi.json'));
  });

  test('serves formatted OpenAPI JSON for direct inspection', () async {
    final app = DartEdge<void>(services: () {});
    app.get('/health', handler: (_) => const {'status': 'ok'});
    OpenApiHelpers.mountJson(app, path: '/openapi.json');

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');
    final response = await (await client.getUrl(
      baseUri.resolve('/openapi.json'),
    )).close();
    final body = await utf8.decoder.bind(response).join();

    expect(body, startsWith('{\n  "openapi": "3.1.0"'));
    expect(body, contains('\n  "paths": {'));
  });

  test(
    'builds OpenAPI paths from compiled routes and inherited router tags',
    () {
      final app = DartEdge<void>(services: () {});
      final api = app.router('/api', tags: const ['api']);
      final users = api.router('/users', tags: const ['users']);

      users.get(
        '/:id',
        options: RouteOptions(summary: 'Load one user.'),
        handler: (_) => const {'ok': true},
      );

      final document = app.buildOpenApiDocumentJson();
      final paths = document['paths']! as Map<String, Object?>;
      final userPath = paths['/api/users/{id}']! as Map<String, Object?>;
      final operation = userPath['get']! as Map<String, Object?>;

      expect(operation['summary'], 'Load one user.');
      expect(operation['tags'], ['api', 'users']);
      expect(operation['parameters'], contains(containsPair('name', 'id')));
    },
  );
}
