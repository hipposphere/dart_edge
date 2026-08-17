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

Reliable streams remain open until they are explicitly finished or reset:

```dart
final audio = await session.openUnidirectionalStream(sendOrder: 10);
await audio.write(metadataBytes);
for (final chunk in audioChunks) {
  await audio.writeLease(chunk);
}
await audio.finish();

await for (final control in session.incomingStreams.bidirectional) {
  await for (final chunk in control.receive.chunks()) {
    handleControlBytes(chunk);
  }
}
```

`writeLease` consumes the lease. Native receive leases retain the Rust-owned
allocation until the consumer closes them, avoiding a Dart-managed byte copy on
the incremental path. `sendStream` and `streams` remain available as
whole-payload compatibility helpers; do not listen to `streams` and
`incomingStreams.unidirectional` at the same time.

Configured handshake headers are forwarded through `WebTransportOptions` on
the browser and through the native CONNECT request on native platforms. This
allows bearer authorization without a WebSocket-style query ticket where the
browser runtime exposes the header option.

The native FFI declarations are generated from
`rust/include/dart_edge_webtransport.h`:

```bash
cd packages/dart_edge_webtransport
dart run ffigen --config tool/ffigen.yaml
```
