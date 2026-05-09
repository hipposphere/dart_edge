import 'dart:typed_data';

/// Accessor for incoming WebTransport datagrams exposed to a route handler.
final class IncomingWebTransportDatagrams {
  const IncomingWebTransportDatagrams([Stream<Uint8List>? datagrams])
    : _datagrams = datagrams ?? const Stream<Uint8List>.empty();

  final Stream<Uint8List> _datagrams;

  /// Incoming unreliable datagrams.
  Stream<Uint8List> datagrams() => _datagrams;
}
