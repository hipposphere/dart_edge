import 'dart:io';

import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart' show Component;
import 'package:jaspr/server.dart' as jaspr_server show Document;
import 'package:test/test.dart';

void main() {
  test('renders Jaspr components into HTML strings', () async {
    final html = await JasprRenderer.renderString(
      jaspr_server.Document(
        title: 'Welcome',
        base: null,
        body: div([Component.text('Hello from Jaspr')]),
      ),
    );

    expect(html, contains('<title>Welcome</title>'));
    expect(html, contains('Hello from Jaspr'));
  });

  test('mounts a Jaspr app as one catch-all Shelf-backed route', () async {
    final app = DartEdge<void>(services: () {});
    app.mountJasprApp(
      jaspr_server.Document(
        title: 'Mounted',
        base: null,
        body: div([Component.text('Mounted body')]),
      ),
      catchAllPath: '/<jasprPath*>',
      paths: const [],
    );

    expect(app.routeRegistry.registrations, hasLength(1));
    expect(app.routeRegistry.registrations.single.httpPath, '/<jasprPath*>');

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');
    final response = await (await client.getUrl(
      baseUri.resolve('/nested/page'),
    )).close();
    final html = await response.transform(SystemEncoding().decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(html, contains('Mounted body'));
  });
}
