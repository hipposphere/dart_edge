import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_runtime/dart_edge_runtime.dart';
import 'package:test/test.dart';

void main() {
  test(
    'serves requests without a services factory when TServices is void',
    () async {
      final app = DartEdge<void>();
      app.get('/hello', handler: (_) => 'Hello, World!');

      final server = await app.listen(port: 0);
      final client = HttpClient();

      addTearDown(() async {
        client.close(force: true);
        await server.close();
      });

      final response = await (await client.getUrl(
        Uri.http('127.0.0.1:${server.port}', '/hello'),
      )).close();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'application/json');
      expect(await utf8.decoder.bind(response).join(), '"Hello, World!"');
    },
  );

  test('binds to an explicit deploy host and serves requests', () async {
    final app = DartEdge<void>(services: () {});
    app.get('/health', handler: (_) => const {'status': 'ok'});

    final server = await app.listen(host: '0.0.0.0', port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    expect(server.host, '0.0.0.0');

    final response = await (await client.getUrl(
      Uri.http('127.0.0.1:${server.port}', '/health'),
    )).close();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, 'application/json');

    final body =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, Object?>;
    expect(body, containsPair('status', 'ok'));
  });

  test('fails to start when the configured host is invalid', () async {
    final app = DartEdge<void>(services: () {});

    await expectLater(
      () => app.listen(host: '256.256.256.256', port: 0),
      throwsA(isA<StateError>()),
    );
  });

  test('runs route guards before the handler and can short-circuit', () async {
    final app = DartEdge<void>(services: () {});
    final protected = app.router(
      '',
      guards: [
        HandlerGuard<void>(
          debugName: 'denyAll',
          handler: (_) => GuardResult.deny(
            RawResponse.text(status: HttpStatus.unauthorized, body: 'blocked'),
          ),
        ),
      ],
    );
    protected.get('/guarded', handler: (_) => 'ok');

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final response = await (await client.getUrl(
      Uri.http('127.0.0.1:${server.port}', '/guarded'),
    )).close();
    expect(response.statusCode, HttpStatus.unauthorized);
    expect(await utf8.decoder.bind(response).join(), 'blocked');
  });

  test('runs inline helper and explicit contract guards', () async {
    final app = DartEdge<void>(services: () {});

    app.get(
      '/inline-guarded',
      guards: [
        HandlerGuard<void>(
          debugName: 'denyInline',
          handler: (_) => GuardResult.deny(
            RawResponse.text(status: HttpStatus.forbidden, body: 'inline'),
          ),
        ),
      ],
      handler: (_) => 'ok',
    );
    app.register(
      _GuardedContractRoute(
        guard: HandlerGuard<void>(
          debugName: 'denyContract',
          handler: (_) => GuardResult.deny(
            RawResponse.text(status: HttpStatus.forbidden, body: 'contract'),
          ),
        ),
      ),
    );

    final server = await app.listen(port: 0);
    final client = HttpClient();

    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });

    final inlineResponse = await (await client.getUrl(
      Uri.http('127.0.0.1:${server.port}', '/inline-guarded'),
    )).close();
    expect(inlineResponse.statusCode, HttpStatus.forbidden);
    expect(await utf8.decoder.bind(inlineResponse).join(), 'inline');

    final contractResponse = await (await client.getUrl(
      Uri.http('127.0.0.1:${server.port}', '/contract-guarded'),
    )).close();
    expect(contractResponse.statusCode, HttpStatus.forbidden);
    expect(await utf8.decoder.bind(contractResponse).join(), 'contract');
  });
}

final class _GuardedContractRoute extends JsonRouteDefinition<void, String> {
  _GuardedContractRoute({required this.guard});

  final Guard<void> guard;

  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/contract-guarded',
    options: RouteOptions(
      operationId: 'contractGuarded',
      success: ResponseSpec.text(),
    ),
    guards: [guard],
  );

  @override
  String handle(RequestContext<void> ctx) => 'ok';
}
