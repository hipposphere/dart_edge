import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../contracts/http/raw_response.dart';
import '../runtime/transport_request.dart';
import 'generated_bindings.dart' as gen;
import 'native_transport_request.dart';

typedef _NativeRequestReady = Void Function(Int64);

abstract final class DartEdgeNative {
  /// ABI version exposed by the bundled native runtime.
  static int get abiVersion => gen.dart_edge_runtime_native_abi_version();

  /// Whether the current process can load the bundled runtime asset.
  static bool get hasBundledRuntime => abiVersion >= 8;

  /// Starts the native HTTP server.
  static int startServer(
    String host,
    int port, {
    required int workers,
    required String routesJson,
    required Pointer<NativeFunction<_NativeRequestReady>> callback,
  }) {
    final hostPtr = host.toNativeUtf8();
    final routesJsonPtr = routesJson.toNativeUtf8();

    try {
      return gen.dart_edge_runtime_start_server(
        hostPtr.cast<Char>(),
        port,
        workers,
        routesJsonPtr.cast<Char>(),
        callback,
      );
    } finally {
      calloc.free(hostPtr);
      calloc.free(routesJsonPtr);
    }
  }

  /// Stops the active native server, if one is running.
  static void stopServer() {
    gen.dart_edge_runtime_stop_server();
  }

  /// Reads one queued request from the native runtime.
  static TransportRequest? takeRequest(int requestId) {
    final requestPtr = gen.dart_edge_runtime_take_request(requestId);
    if (requestPtr == nullptr) {
      return null;
    }

    try {
      return decodeNativeTransportRequest(requestPtr);
    } finally {
      gen.dart_edge_runtime_free_request(requestPtr);
    }
  }

  /// Attempts to send a response for a previously taken request.
  static bool tryRespond(
    int requestId, {
    required int status,
    required String contentType,
    required String body,
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    final contentTypePtr = contentType.toNativeUtf8();
    final bodyPtr = body.toNativeUtf8();
    final nativeHeaders = [
      for (final header in headers)
        (
          nameLength: utf8.encode(header.name).length,
          key: header.name.toNativeUtf8(),
          valueLength: utf8.encode(header.value).length,
          value: header.value.toNativeUtf8(),
        ),
    ];
    final headerStorage = calloc<gen.NativePair>(nativeHeaders.length);

    try {
      for (var index = 0; index < nativeHeaders.length; index += 1) {
        (headerStorage + index).ref
          ..key.ptr = nativeHeaders[index].key.cast<Uint8>()
          ..key.len = nativeHeaders[index].nameLength
          ..value.ptr = nativeHeaders[index].value.cast<Uint8>()
          ..value.len = nativeHeaders[index].valueLength;
      }

      return gen.dart_edge_runtime_send_response(
        requestId,
        status,
        contentTypePtr.cast<Char>(),
        bodyPtr.cast<Char>(),
        nativeHeaders.length,
        nativeHeaders.isEmpty ? nullptr : headerStorage,
      );
    } finally {
      calloc.free(headerStorage);
      for (final header in nativeHeaders) {
        calloc.free(header.key);
        calloc.free(header.value);
      }
      calloc.free(contentTypePtr);
      calloc.free(bodyPtr);
    }
  }
}
