import 'dart:typed_data';

/// Accessor for incoming reliable WebTransport stream payloads.
///
/// Each item is the full payload from one completed unidirectional
/// WebTransport stream.
final class IncomingWebTransportStreams {
  const IncomingWebTransportStreams([Stream<Uint8List>? streams])
    : _streams = streams ?? const Stream<Uint8List>.empty();

  final Stream<Uint8List> _streams;

  /// Incoming reliable stream payloads.
  Stream<Uint8List> streams() => _streams;
}
