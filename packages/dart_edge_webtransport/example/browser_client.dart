import 'dart:convert';

import 'package:dart_edge_webtransport/dart_edge_webtransport.dart';

Future<void> main() async {
  final client = DartEdgeWebTransportClient();
  final session = await client.connect(
    Uri.parse('https://localhost:4433/events'),
  );

  await session.sendDatagram(utf8.encode('ping'));
  await for (final datagram in session.datagrams) {
    print(utf8.decode(datagram));
  }
}
