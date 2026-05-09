import 'dart:convert';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_webtransport/dart_edge_webtransport.dart';

Future<void> main() async {
  final client = ExampleRealtimeClient(
    baseUri: Uri.parse('https://localhost:8080'),
    transport: _UnusedHttpTransport(),
    webTransportTransport: DartEdgeWebTransportClientTransport(
      allowSelfSignedCertificates: true,
    ),
    defaultHeaders: const {'authorization': 'Bearer dev-token'},
  );

  final session = await client.connectEvents();
  await session.sendDatagram(utf8.encode('ping'));

  await for (final datagram in session.datagrams) {
    print(utf8.decode(datagram));
    await session.close();
    break;
  }
}

final class ExampleRealtimeClient extends DartEdgeHttpClientBase {
  const ExampleRealtimeClient({
    required super.baseUri,
    required super.transport,
    super.webTransportTransport,
    super.defaultHeaders,
  });

  Future<DartEdgeClientWebTransportSession> connectEvents() {
    return connectWebTransport<Never, Never, Never>(
      const DartEdgeClientWebTransportInvocation(pathTemplate: '/api/events'),
    );
  }
}

final class _UnusedHttpTransport implements DartEdgeClientTransport {
  @override
  Future<DartEdgeClientResponse> send(DartEdgeClientRequest request) {
    throw UnsupportedError('This example only opens a WebTransport session.');
  }
}
