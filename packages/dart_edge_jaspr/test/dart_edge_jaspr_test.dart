import 'dart:io';

import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart' show Component;
import 'package:jaspr/server.dart' as jaspr_server show Document;
import 'package:test/test.dart';

void main() {
  test('renders Jaspr documents into HTML responses', () async {
    final response = await JasprRenderer.document(
      title: 'Welcome',
      base: null,
      body: div([Component.text('Hello from Jaspr')]),
    );

    expect(response.status, 200);
    expect(response.contentType, 'text/html; charset=utf-8');
    expect(response.body, contains('<title>Welcome</title>'));
    expect(response.body, contains('Hello from Jaspr'));
  });

  test('registers Jaspr-backed HTML routes on a DartEdge app', () async {
    final app = DartEdge<void>(services: () {});

    app.getJaspr(
      '/preview',
      options: const RouteOptions(summary: 'Preview an HTML page.'),
      handler: (_) => jaspr_server.Document(
        title: 'Preview',
        base: null,
        body: div([Component.text('Preview body')]),
      ),
    );

    final registration = app.routeRegistry.registrations.single;
    final contract =
        (registration.route as JsonRouteDefinition<void, dynamic>).contract
            as RouteContract;

    expect(contract.options.summary, 'Preview an HTML page.');
    expect(contract.responses.success.contentType, 'text/html; charset=utf-8');

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');
    final response = await (await client.getUrl(
      baseUri.resolve('/preview'),
    )).close();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, 'text/html');

    final html = await response.transform(SystemEncoding().decoder).join();
    expect(html, contains('<title>Preview</title>'));
    expect(html, contains('Preview body'));
  });
}
