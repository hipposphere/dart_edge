import 'dart:io';

import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_shelf/dart_edge_shelf.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

void main() {
  test('mounts a Shelf handler as a Dart Edge catch-all route', () async {
    final app = DartEdge<void>(services: () {});

    app.mountShelfHandler(
      (request) => shelf.Response.ok(
        'method=${request.method};url=${request.url}',
        headers: {'content-type': 'text/plain; charset=utf-8'},
      ),
      methods: const [HttpMethod.get],
    );

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final baseUri = Uri.http('127.0.0.1:${server.port}');
    final rootResponse = await (await client.getUrl(
      baseUri.resolve('/'),
    )).close();
    final rootBody = await rootResponse
        .transform(SystemEncoding().decoder)
        .join();

    expect(rootResponse.statusCode, HttpStatus.ok);
    expect(rootBody, 'method=GET;url=');

    final nestedResponse = await (await client.getUrl(
      baseUri.resolve('/assets/styles.css?v=1'),
    )).close();
    final nestedBody = await nestedResponse
        .transform(SystemEncoding().decoder)
        .join();

    expect(nestedResponse.statusCode, HttpStatus.ok);
    expect(nestedBody, 'method=GET;url=assets/styles.css?v=1');
  });

  test('forwards request bodies to Shelf handlers', () async {
    final app = DartEdge<void>(services: () {});

    app.mountShelfHandler((request) async {
      final body = await request.readAsString();
      return shelf.Response.ok(
        body,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }, methods: const [HttpMethod.post]);

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final request = await client.postUrl(
      Uri.http('127.0.0.1:${server.port}', '/echo'),
    );
    request.write('hello shelf');
    final response = await request.close();
    final body = await response.transform(SystemEncoding().decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(body, 'hello shelf');
  });
}
