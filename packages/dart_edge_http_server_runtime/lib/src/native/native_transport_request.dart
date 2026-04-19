import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/ffi.dart' as core_ffi;

import '../runtime/transport_request.dart';
import 'generated_bindings.dart';

TransportRequest decodeNativeTransportRequest(
  Pointer<NativeTransportRequest> requestPtr,
) {
  final request = requestPtr.ref;

  return TransportRequest(
    routeId: _decodeUtf8(request.route_id),
    pathParams: _decodePairs(request.path_params, request.path_param_count),
    query: _decodePairs(request.query, request.query_count),
    headers: _decodePairs(request.headers, request.header_count),
    bodyBytes: _readBytes(request.body),
    bodyKind: switch (request.body_kind) {
      1 => TransportRequestBodyKind.text,
      2 => TransportRequestBodyKind.json,
      _ => TransportRequestBodyKind.none,
    },
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

String _decodeUtf8(core_ffi.NativeBytes value) =>
    core_ffi.decodeNativeUtf8(value);

Uint8List? _readBytes(core_ffi.NativeBytes value) =>
    core_ffi.maybeCopyNativeBytes(value);
