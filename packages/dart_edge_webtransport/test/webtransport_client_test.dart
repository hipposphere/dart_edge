import 'dart:async';
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
          final connected = await transport.openUnidirectionalStream();
          await connected.write(Uint8List.fromList([9]));
          await connected.finish();
          await for (final stream in transport.incomingStreams.unidirectional) {
            final bytes = <int>[];
            await for (final lease in stream.leases()) {
              try {
                bytes.addAll(lease.bytesView);
              } finally {
                lease.close();
              }
            }
            await transport.sendStream(bytes);
          }
        },
      );

      final server = await app.listen(port: 0);
      final port = server.port;

      try {
        final received = await _connectAndEchoDatagram(
          port,
        ).timeout(const Duration(seconds: 10));
        final receivedStreams = await _connectAndEchoStream(
          port,
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

  test(
    'keeps native uni and bidirectional streams open across writes',
    () async {
      final app = DartEdge<void>(services: () {});
      app.webtransport(
        '/persistent-uni',
        options: const WebTransportOptions(operationId: 'persistentUni'),
        onConnect: (transport) async {
          final incoming = await transport.incomingStreams.unidirectional.first;
          final received = await _collectLeases(incoming);
          final response = await transport.openUnidirectionalStream();
          await response.write(const [90]);
          await response.write(received);
          await response.finish();
          await transport.sendDatagram(const [92]);
        },
      );
      app.webtransport(
        '/persistent-bidi',
        options: const WebTransportOptions(operationId: 'persistentBidi'),
        onConnect: (transport) async {
          final stream = await transport.incomingStreams.bidirectional.first;
          final received = await _collectLeases(stream.receive);
          await stream.send.write(received.reversed.toList());
          await stream.send.write(const [91]);
          await stream.send.finish();
          await transport.sendDatagram(const [93]);
        },
      );

      final server = await app.listen(port: 0);
      try {
        final uni = await _connectPersistentUni(
          server.port,
        ).timeout(const Duration(seconds: 10));
        final bidi = await _connectPersistentBidi(
          server.port,
        ).timeout(const Duration(seconds: 10));

        expect(uni, [90, 1, 2, 3, 4]);
        expect(bidi, [4, 3, 2, 1, 91]);
      } finally {
        await server.close();
      }
    },
  );
}

Future<List<int>> _connectPersistentUni(int port) async {
  final session = await DartEdgeWebTransportClient(
    allowSelfSignedCertificates: true,
  ).connect(Uri.parse('https://127.0.0.1:$port/persistent-uni'));
  try {
    final completed = session.datagrams.first;
    final response = session.incomingStreams.unidirectional.first;
    final request = await session.openUnidirectionalStream(sendOrder: 5);
    await request.write(const [1, 2]);
    await request.writeLease(
      BinaryPayloadLease.fromBytes(Uint8List.fromList([3, 4])),
    );
    await request.finish();
    final result = await _collectLeases(await response);
    expect(await completed, [92]);
    return result;
  } finally {
    await session.close(reason: 'persistent uni complete');
  }
}

Future<List<int>> _connectPersistentBidi(int port) async {
  final session = await DartEdgeWebTransportClient(
    allowSelfSignedCertificates: true,
  ).connect(Uri.parse('https://127.0.0.1:$port/persistent-bidi'));
  try {
    final completed = session.datagrams.first;
    final stream = await session.openBidirectionalStream(sendOrder: 10);
    final response = _collectLeases(stream.receive);
    await stream.send.write(const [1, 2]);
    await stream.send.writeLease(
      BinaryPayloadLease.fromBytes(Uint8List.fromList([3, 4])),
    );
    await stream.send.finish();
    final result = await response;
    expect(await completed, [93]);
    return result;
  } finally {
    await session.close(reason: 'persistent bidi complete');
  }
}

Future<List<int>> _collectLeases(WebTransportReceiveStream stream) async {
  final bytes = <int>[];
  await for (final lease in stream.leases()) {
    try {
      bytes.addAll(lease.bytesView);
    } finally {
      lease.close();
    }
  }
  return bytes;
}

Future<List<Uint8List>> _connectAndEchoDatagram(int port) async {
  final client = DartEdgeWebTransportClient(allowSelfSignedCertificates: true);
  final session = await client
      .connect(
        Uri.parse('https://127.0.0.1:$port/events'),
        headers: const {'authorization': 'Bearer dev-token'},
      )
      .timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('datagram connect timed out'),
      );

  try {
    final datagrams = StreamIterator(session.datagrams);
    await datagrams.moveNext().timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw StateError('initial datagram timed out'),
    );
    final connected = datagrams.current;
    await session
        .sendDatagram(Uint8List.fromList([1, 2, 3]))
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw StateError('datagram send timed out'),
        );
    await datagrams.moveNext().timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw StateError('echoed datagram timed out'),
    );
    final echoed = datagrams.current;
    await datagrams.cancel();
    return [connected, echoed];
  } finally {
    await session
        .close(code: 0, reason: 'test complete')
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw StateError('datagram close timed out'),
        );
  }
}

Future<List<Uint8List>> _connectAndEchoStream(int port) async {
  final client = DartEdgeWebTransportClient(allowSelfSignedCertificates: true);
  final session = await client
      .connect(
        Uri.parse('https://127.0.0.1:$port/streams'),
        headers: const {'authorization': 'Bearer dev-token'},
      )
      .timeout(const Duration(seconds: 3));

  try {
    final streams = StreamIterator(session.streams);
    await streams.moveNext().timeout(const Duration(seconds: 3));
    final connected = streams.current;
    await session
        .sendStream(Uint8List.fromList([4, 5, 6]))
        .timeout(const Duration(seconds: 3));
    await streams.moveNext().timeout(const Duration(seconds: 3));
    final echoed = streams.current;
    await streams.cancel().timeout(const Duration(seconds: 3));
    return [connected, echoed];
  } finally {
    await session
        .close(code: 0, reason: 'test complete')
        .timeout(const Duration(seconds: 3));
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
  _FakeWebTransportSession(this.datagrams, this.streams)
    : incomingStreams = const IncomingWebTransportReceiveStreams();

  @override
  final Stream<Uint8List> datagrams;

  @override
  final Stream<Uint8List> streams;

  @override
  final IncomingWebTransportReceiveStreams incomingStreams;

  final List<List<int>> sentDatagrams = <List<int>>[];
  final List<List<int>> sentStreams = <List<int>>[];
  int? closeCode;
  String? closeReason;

  @override
  Future<WebTransportSendStream> openUnidirectionalStream({
    int? sendOrder,
  }) async => _fakeSendStream(sentStreams.length + 1);

  @override
  Future<WebTransportBidirectionalStream> openBidirectionalStream({
    int? sendOrder,
  }) async => WebTransportBidirectionalStream(
    receive: WebTransportReceiveStream(
      id: 1,
      protocolId: null,
      leases: const Stream<BinaryPayloadLease>.empty(),
      stop: ([errorCode = 0]) async {},
    ),
    send: _fakeSendStream(1),
  );

  WebTransportSendStream _fakeSendStream(int id) => WebTransportSendStream(
    id: id,
    protocolId: null,
    write: (value) async => sentStreams.add(List<int>.of(value)),
    writeLease: (lease) async {
      sentStreams.add(List<int>.of(lease.bytesView));
      lease.close();
    },
    finish: () async {},
    reset: ([errorCode = 0]) async {},
  );

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
