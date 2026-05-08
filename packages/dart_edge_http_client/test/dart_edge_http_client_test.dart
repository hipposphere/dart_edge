import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_http_client/dart_edge_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DartEdgeHttpClientTransport', () {
    test(
      'sends requests through package:http and applies interceptors',
      () async {
        final transport = DartEdgeHttpClientTransport(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url, Uri.parse('https://api.example.test/hello'));
            expect(request.headers['authorization'], 'Bearer test-token');
            return http.Response(
              'ok',
              200,
              headers: {'content-type': 'text/plain; charset=utf-8'},
            );
          }),
          interceptors: [
            DartEdgeBearerTokenInterceptor(() async => 'test-token').call,
          ],
        );

        final response = await transport.send(
          DartEdgeClientRequest(
            method: HttpMethod.get,
            uri: Uri.parse('https://api.example.test/hello'),
          ),
        );

        expect(response.status, 200);
        expect(response.contentType, 'text/plain; charset=utf-8');
        expect(response.body, 'ok');
        expect(response.bodyBytes, utf8.encode('ok'));
      },
    );
  });

  group('DartEdgeWebSocketClientTransport', () {
    test('connects through web_socket_client and maps messages', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((message) {
          socket.add(message);
        });
      });

      final transport = DartEdgeWebSocketClientTransport(
        backoff: const ConstantBackoff(Duration.zero),
      );
      final socket = await transport.connect(
        DartEdgeClientWebSocketRequest(
          uri: Uri.parse('ws://${server.address.host}:${server.port}/socket'),
        ),
      );
      addTearDown(() => socket.close());

      final echo = Completer<WebSocketMessage>();
      final subscription = socket.messages.listen((message) {
        if (!echo.isCompleted) {
          echo.complete(message);
        }
      });
      addTearDown(subscription.cancel);

      await socket.sendJson({'ok': true});
      final second = await echo.future.timeout(const Duration(seconds: 5));
      expect(second.kind, WebSocketMessageKind.text);
      expect(jsonDecode(second.text), {'ok': true});
    });
  });
}
