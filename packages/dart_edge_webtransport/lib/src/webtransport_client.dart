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
  /// Browser runtimes cannot send forbidden request headers such as `cookie`.
  /// Native runtimes pass headers through to the HTTP/3 CONNECT request.
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

  /// Incoming reliable stream payloads.
  Stream<Uint8List> get streams;

  /// Sends one unreliable datagram.
  Future<void> sendDatagram(List<int> bytes);

  /// Sends one reliable payload on a new unidirectional WebTransport stream.
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
