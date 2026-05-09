import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_webtransport/dart_edge_webtransport.dart';
import 'package:test/test.dart';

void main() {
  test('creates the platform WebTransport client', () {
    final client = DartEdgeWebTransportClient();

    expect(client, isA<DartEdgeWebTransportClient>());
  });

  test('formats WebTransport exceptions', () {
    const exception = DartEdgeWebTransportException('failed');

    expect(exception.toString(), 'DartEdgeWebTransportException: failed');
  });

  test('adapts generated client webtransport requests', () async {
    final datagrams = StreamController<Uint8List>();
    final streams = StreamController<Uint8List>();
    final nativeSession = _FakeWebTransportSession(
      datagrams.stream,
      streams.stream,
    );
    final nativeClient = _FakeWebTransportClient(nativeSession);
    final transport = DartEdgeWebTransportClientTransport(client: nativeClient);

    final session = await transport.connect(
      DartEdgeClientWebTransportRequest(
        uri: Uri.parse('https://localhost:8080/api/events'),
        headers: const {'authorization': 'Bearer dev-token'},
      ),
    );

    expect(nativeClient.uri, Uri.parse('https://localhost:8080/api/events'));
    expect(nativeClient.headers, const {'authorization': 'Bearer dev-token'});

    await session.sendDatagram(const [1, 2, 3]);
    expect(nativeSession.sentDatagrams, [
      [1, 2, 3],
    ]);
    await session.sendStream(const [7, 8, 9]);
    expect(nativeSession.sentStreams, [
      [7, 8, 9],
    ]);

    final received = session.datagrams.first;
    datagrams.add(Uint8List.fromList([4, 5, 6]));
    expect(await received, [4, 5, 6]);
    final receivedStream = session.streams.first;
    streams.add(Uint8List.fromList([10, 11, 12]));
    expect(await receivedStream, [10, 11, 12]);

    await session.close(42, 'done');
    expect(nativeSession.closeCode, 42);
    expect(nativeSession.closeReason, 'done');

    await datagrams.close();
    await streams.close();
  });

  test(
    'connects to a Dart Edge WebTransport datagram and stream route',
    () async {
      final app = DartEdge<void>(services: () {});
      app.webtransport(
        '/events',
        options: const WebTransportOptions(operationId: 'connectEvents'),
        onConnect: (transport) async {
          await transport.sendDatagram(Uint8List.fromList([0]));
          await for (final datagram in transport.datagrams.datagrams()) {
            await transport.sendDatagram(datagram);
          }
        },
      );
      app.webtransport(
        '/streams',
        options: const WebTransportOptions(operationId: 'connectStreams'),
        onConnect: (transport) async {
          await transport.sendStream(Uint8List.fromList([9]));
          await for (final stream in transport.streams.streams()) {
            await transport.sendStream(stream);
          }
        },
      );

      final server = await app.listen(port: 0);
      final port = server.port;

      try {
        final received = await Isolate.run(
          () => _connectAndEchoDatagram(port),
        ).timeout(const Duration(seconds: 10));
        final receivedStreams = await Isolate.run(
          () => _connectAndEchoStream(port),
        ).timeout(const Duration(seconds: 10));

        expect(received, [
          [0],
          [1, 2, 3],
        ]);
        expect(receivedStreams, [
          [9],
          [4, 5, 6],
        ]);
      } finally {
        await server.close();
      }
    },
  );
}

Future<List<Uint8List>> _connectAndEchoDatagram(int port) async {
  final client = DartEdgeWebTransportClient(allowSelfSignedCertificates: true);
  final session = await client.connect(
    Uri.parse('https://127.0.0.1:$port/events'),
    headers: const {'authorization': 'Bearer dev-token'},
  );

  try {
    final datagrams = StreamIterator(session.datagrams);
    await datagrams.moveNext();
    final connected = datagrams.current;
    await session.sendDatagram(Uint8List.fromList([1, 2, 3]));
    await datagrams.moveNext();
    final echoed = datagrams.current;
    await datagrams.cancel();
    return [connected, echoed];
  } finally {
    await session.close(code: 0, reason: 'test complete');
  }
}

Future<List<Uint8List>> _connectAndEchoStream(int port) async {
  final client = DartEdgeWebTransportClient(allowSelfSignedCertificates: true);
  final session = await client.connect(
    Uri.parse('https://127.0.0.1:$port/streams'),
    headers: const {'authorization': 'Bearer dev-token'},
  );

  try {
    final streams = StreamIterator(session.streams);
    await streams.moveNext();
    final connected = streams.current;
    await session.sendStream(Uint8List.fromList([4, 5, 6]));
    await streams.moveNext();
    final echoed = streams.current;
    await streams.cancel();
    return [connected, echoed];
  } finally {
    await session.close(code: 0, reason: 'test complete');
  }
}

final class _FakeWebTransportClient implements DartEdgeWebTransportClient {
  _FakeWebTransportClient(this.session);

  final DartEdgeWebTransportSession session;
  Uri? uri;
  Map<String, String>? headers;

  @override
  Future<DartEdgeWebTransportSession> connect(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    this.uri = uri;
    this.headers = headers;
    return session;
  }
}

final class _FakeWebTransportSession implements DartEdgeWebTransportSession {
  _FakeWebTransportSession(this.datagrams, this.streams);

  @override
  final Stream<Uint8List> datagrams;

  @override
  final Stream<Uint8List> streams;

  final List<List<int>> sentDatagrams = <List<int>>[];
  final List<List<int>> sentStreams = <List<int>>[];
  int? closeCode;
  String? closeReason;

  @override
  Future<void> sendDatagram(List<int> bytes) async {
    sentDatagrams.add(List<int>.of(bytes));
  }

  @override
  Future<void> sendStream(List<int> bytes) async {
    sentStreams.add(List<int>.of(bytes));
  }

  @override
  Future<void> close({int code = 0, String reason = ''}) async {
    closeCode = code;
    closeReason = reason;
  }
}
