# dart_edge_webtransport

Cross-platform WebTransport client support for Dart Edge.

The browser implementation uses the platform `WebTransport` API through
`package:web`. The native implementation is backed by Rust and `wtransport`
through Dart native assets.

```dart
import 'dart:convert';

import 'package:dart_edge_webtransport/dart_edge_webtransport.dart';

Future<void> main() async {
  final client = DartEdgeWebTransportClient();
  final session = await client.connect(
    Uri.parse('https://api.example.test/events'),
    headers: {'authorization': 'Bearer token'},
  );

  await session.sendDatagram(utf8.encode('hello'));
  await for (final datagram in session.datagrams) {
    print(utf8.decode(datagram));
  }
}
```

Browser cookie headers cannot be set manually. Use browser-managed cookies or
bearer-style headers when the browser allows the requested header.
