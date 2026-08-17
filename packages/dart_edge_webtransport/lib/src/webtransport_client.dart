import 'dart:async';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'platform/webtransport_client_platform.dart'
    if (dart.library.js_interop) 'platform/webtransport_client_web.dart'
    if (dart.library.ffi) 'platform/webtransport_client_native.dart';

/// Creates WebTransport client sessions.
abstract interface class DartEdgeWebTransportClient {
  /// Returns the platform implementation for the current runtime.
  factory DartEdgeWebTransportClient({bool allowSelfSignedCertificates}) =
      PlatformWebTransportClient;

  /// Opens a WebTransport session.
  ///
  /// Browser and native runtimes pass [headers] through to the WebTransport
  /// CONNECT request. Browser support follows `WebTransportOptions.headers`.
  Future<DartEdgeWebTransportSession> connect(
    Uri uri, {
    Map<String, String> headers,
  });
}

/// Generated-client WebTransport transport backed by [DartEdgeWebTransportClient].
final class DartEdgeWebTransportClientTransport
    implements DartEdgeClientWebTransportTransport {
  DartEdgeWebTransportClientTransport({
    DartEdgeWebTransportClient? client,
    bool allowSelfSignedCertificates = false,
  }) : client =
           client ??
           DartEdgeWebTransportClient(
             allowSelfSignedCertificates: allowSelfSignedCertificates,
           );

  final DartEdgeWebTransportClient client;

  @override
  Future<DartEdgeClientWebTransportSession> connect(
    DartEdgeClientWebTransportRequest request,
  ) async {
    final session = await client.connect(request.uri, headers: request.headers);
    return _DartEdgeClientWebTransportSession(session);
  }
}

final class _DartEdgeClientWebTransportSession
    implements DartEdgeClientWebTransportSession {
  const _DartEdgeClientWebTransportSession(this._session);

  final DartEdgeWebTransportSession _session;

  @override
  Stream<Uint8List> get datagrams => _session.datagrams;

  @override
  IncomingWebTransportReceiveStreams get incomingStreams =>
      _session.incomingStreams;

  @override
  Future<WebTransportSendStream> openUnidirectionalStream({int? sendOrder}) {
    return _session.openUnidirectionalStream(sendOrder: sendOrder);
  }

  @override
  Future<WebTransportBidirectionalStream> openBidirectionalStream({
    int? sendOrder,
  }) {
    return _session.openBidirectionalStream(sendOrder: sendOrder);
  }

  @override
  Stream<Uint8List> get streams => _session.streams;

  @override
  Future<void> close([int? code, String? reason]) {
    return _session.close(code: code ?? 0, reason: reason ?? '');
  }

  @override
  Future<void> sendDatagram(List<int> value) {
    return _session.sendDatagram(value);
  }

  @override
  Future<void> sendStream(List<int> value) {
    return _session.sendStream(value);
  }
}

/// An active WebTransport session.
abstract interface class DartEdgeWebTransportSession {
  /// Incoming unreliable datagrams.
  Stream<Uint8List> get datagrams;

  /// Incoming long-lived reliable streams initiated by the peer.
  IncomingWebTransportReceiveStreams get incomingStreams;

  /// Opens a long-lived client-to-server reliable stream.
  ///
  /// Streams with a higher [sendOrder] are scheduled before streams with a
  /// lower value when both have buffered data.
  Future<WebTransportSendStream> openUnidirectionalStream({int? sendOrder});

  /// Opens a long-lived reliable stream with independent send/receive halves.
  ///
  /// Streams with a higher [sendOrder] are scheduled before streams with a
  /// lower value when both have buffered data.
  Future<WebTransportBidirectionalStream> openBidirectionalStream({
    int? sendOrder,
  });

  /// Complete incoming reliable stream payloads.
  ///
  /// This compatibility surface must not be listened to at the same time as
  /// [incomingStreams]. Prefer [incomingStreams] for incremental processing.
  Stream<Uint8List> get streams;

  /// Sends one unreliable datagram.
  Future<void> sendDatagram(List<int> bytes);

  /// Sends one complete payload on a new unidirectional WebTransport stream.
  Future<void> sendStream(List<int> bytes);

  /// Closes the session.
  Future<void> close({int code, String reason});
}

/// Error raised by WebTransport client implementations.
final class DartEdgeWebTransportException implements Exception {
  const DartEdgeWebTransportException(this.message);

  final String message;

  @override
  String toString() => 'DartEdgeWebTransportException: $message';
}
