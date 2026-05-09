import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;

import 'generated_bindings.dart' as gen;

final class NativeWebTransportConnection {
  const NativeWebTransportConnection({
    required this.sessionId,
    required this.requestId,
    required this.routeId,
    required this.pathParams,
    required this.query,
    required this.headers,
  });

  final int sessionId;
  final int requestId;
  final String routeId;
  final Map<String, String> pathParams;
  final Map<String, String> query;
  final Map<String, String> headers;
}

final class NativeWebTransportDatagram {
  const NativeWebTransportDatagram({
    required this.sessionId,
    required this.body,
  });

  final int sessionId;
  final Uint8List body;
}

final class NativeWebTransportStream {
  const NativeWebTransportStream({required this.sessionId, required this.body});

  final int sessionId;
  final Uint8List body;
}

NativeWebTransportConnection decodeNativeWebTransportConnection(
  Pointer<gen.NativeWebTransportConnection> connectionPtr,
) {
  final connection = connectionPtr.ref;
  return NativeWebTransportConnection(
    sessionId: connection.session_id,
    requestId: connection.request_id,
    routeId: core_ffi.decodeNativeUtf8(connection.route_id),
    pathParams: _decodePairs(
      connection.path_params,
      connection.path_param_count,
    ),
    query: _decodePairs(connection.query, connection.query_count),
    headers: _decodePairs(connection.headers, connection.header_count),
  );
}

NativeWebTransportDatagram decodeNativeWebTransportDatagram(
  Pointer<gen.NativeWebTransportDatagram> datagramPtr,
) {
  final datagram = datagramPtr.ref;
  return NativeWebTransportDatagram(
    sessionId: datagram.session_id,
    body: core_ffi.maybeCopyNativeBytes(datagram.body) ?? Uint8List(0),
  );
}

NativeWebTransportStream decodeNativeWebTransportStream(
  Pointer<gen.NativeWebTransportStream> streamPtr,
) {
  final stream = streamPtr.ref;
  return NativeWebTransportStream(
    sessionId: stream.session_id,
    body: core_ffi.maybeCopyNativeBytes(stream.body) ?? Uint8List(0),
  );
}

Map<String, String> _decodePairs(
  Pointer<core_ffi.NativePair> pairs,
  int count,
) {
  return {
    for (final pair in core_ffi.copyNativePairs(pairs, count))
      pair.key: pair.value,
  };
}
