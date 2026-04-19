import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

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

Map<String, String> _decodePairs(Pointer<NativePair> pairs, int count) {
  if (count == 0 || pairs == nullptr) {
    return const <String, String>{};
  }

  return {
    for (var index = 0; index < count; index += 1)
      _decodeUtf8((pairs + index).ref.key): _decodeUtf8(
        (pairs + index).ref.value,
      ),
  };
}

String _decodeUtf8(NativeBytes value) {
  final bytes = _readBytes(value);
  if (bytes == null || bytes.isEmpty) {
    return '';
  }
  return utf8.decode(bytes);
}

Uint8List? _readBytes(NativeBytes value) {
  if (value.len == 0 || value.ptr == nullptr) {
    return null;
  }

  return Uint8List.fromList(value.ptr.asTypedList(value.len));
}
