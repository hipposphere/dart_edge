import 'dart:convert';
import 'dart:ffi';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_core/ffi.dart' as core_ffi;
import 'package:ffi/ffi.dart';

import '../runtime/native_request.dart';
import '../runtime/transport_request.dart';
import 'generated_bindings.dart' as gen;
import 'native_transport_request.dart';
import 'native_transport_web_socket.dart';

typedef _NativeTransportEvent = Void Function(Int32, Int64);

final class NativeTransportRequestLease {
  NativeTransportRequestLease._({
    required this.request,
    required this.nativeRequest,
    required Pointer<gen.NativeTransportRequest> requestPtr,
    this.releaseNativeBody,
  }) : _requestPtr = requestPtr;

  final TransportRequest request;
  final NativeRequest nativeRequest;
  final void Function()? releaseNativeBody;
  final Pointer<gen.NativeTransportRequest> _requestPtr;
  var _disposed = false;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    releaseNativeBody?.call();
    gen.dart_edge_http_server_runtime_free_request(_requestPtr);
  }
}

abstract final class DartEdgeNative {
  /// ABI version exposed by the bundled native runtime.
  static int get abiVersion =>
      gen.dart_edge_http_server_runtime_native_abi_version();

  /// Whether the current process can load the bundled runtime asset.
  static bool get hasBundledRuntime => abiVersion >= 10;

  /// Starts the native HTTP server.
  static int startServer(
    String host,
    int port, {
    required int workers,
    required String routesJson,
    required Pointer<NativeFunction<_NativeTransportEvent>> callback,
  }) {
    final hostPtr = host.toNativeUtf8();
    final routesJsonPtr = routesJson.toNativeUtf8();

    try {
      return gen.dart_edge_http_server_runtime_start_server(
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
    gen.dart_edge_http_server_runtime_stop_server();
  }

  /// Reads one queued request from the native runtime.
  static NativeTransportRequestLease? takeRequest(int requestId) {
    final requestPtr = gen.dart_edge_http_server_runtime_take_request(
      requestId,
    );
    if (requestPtr == nullptr) {
      return null;
    }

    final decoded = decodeNativeTransportRequest(requestPtr);
    return NativeTransportRequestLease._(
      request: decoded.request,
      nativeRequest: decoded.nativeRequest,
      requestPtr: requestPtr,
      releaseNativeBody: decoded.releaseNativeBody,
    );
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
    try {
      return _withNativeHeaders(
        headers,
        (headerStorage, headerCount) =>
            gen.dart_edge_http_server_runtime_send_response(
              requestId,
              status,
              contentTypePtr.cast<Char>(),
              bodyPtr.cast<Char>(),
              headerCount,
              headerStorage,
            ),
      );
    } finally {
      calloc.free(contentTypePtr);
      calloc.free(bodyPtr);
    }
  }

  /// Accepts a pending WebSocket upgrade request.
  static bool acceptWebSocket(
    int requestId, {
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    return _withNativeHeaders(
      headers,
      (headerStorage, headerCount) =>
          gen.dart_edge_http_server_runtime_accept_web_socket(
            requestId,
            headerCount,
            headerStorage,
          ),
    );
  }

  /// Starts an SSE response for a previously taken request.
  static bool startSseResponse(
    int requestId, {
    required int status,
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    return _withNativeHeaders(
      headers,
      (headerStorage, headerCount) =>
          gen.dart_edge_http_server_runtime_start_sse_response(
            requestId,
            status,
            headerCount,
            headerStorage,
          ),
    );
  }

  /// Sends one encoded SSE chunk for an active streaming response.
  static bool sendSseChunk(int requestId, String chunk) {
    final chunkPtr = chunk.toNativeUtf8();
    try {
      return gen.dart_edge_http_server_runtime_send_sse_chunk(
        requestId,
        chunkPtr.cast<Char>(),
      );
    } finally {
      calloc.free(chunkPtr);
    }
  }

  /// Finishes an active SSE response.
  static bool finishSseResponse(int requestId) {
    return gen.dart_edge_http_server_runtime_finish_sse_response(requestId);
  }

  /// Reads one queued WebSocket connection open event from the native runtime.
  static NativeWebSocketConnection? takeWebSocketConnection(int sessionId) {
    final connectionPtr = gen
        .dart_edge_http_server_runtime_take_web_socket_connection(sessionId);
    if (connectionPtr == nullptr) {
      return null;
    }

    try {
      return decodeNativeWebSocketConnection(connectionPtr);
    } finally {
      gen.dart_edge_http_server_runtime_free_web_socket_connection(
        connectionPtr,
      );
    }
  }

  /// Reads one queued WebSocket text message from the native runtime.
  static NativeWebSocketMessage? takeWebSocketMessage(int sessionId) {
    final messagePtr = gen
        .dart_edge_http_server_runtime_take_web_socket_message(sessionId);
    if (messagePtr == nullptr) {
      return null;
    }

    try {
      return decodeNativeWebSocketMessage(messagePtr);
    } finally {
      gen.dart_edge_http_server_runtime_free_web_socket_message(messagePtr);
    }
  }

  /// Sends a text frame over an active WebSocket session.
  static bool webSocketSendText(int sessionId, String text) {
    final textPtr = text.toNativeUtf8();
    try {
      return gen.dart_edge_http_server_runtime_web_socket_send_text(
        sessionId,
        textPtr.cast<Char>(),
      );
    } finally {
      calloc.free(textPtr);
    }
  }

  /// Closes an active WebSocket session.
  static bool webSocketClose(int sessionId, {int? code, String? reason}) {
    final reasonPtr = reason?.toNativeUtf8();
    try {
      return gen.dart_edge_http_server_runtime_web_socket_close(
        sessionId,
        code ?? 0,
        reasonPtr?.cast<Char>() ?? nullptr,
      );
    } finally {
      if (reasonPtr != null) {
        calloc.free(reasonPtr);
      }
    }
  }
}

T _withNativeHeaders<T>(
  List<HttpHeader> headers,
  T Function(Pointer<core_ffi.NativePair> headerStorage, int headerCount) run,
) {
  final nativeHeaders = [
    for (final header in headers)
      (
        nameLength: utf8.encode(header.name).length,
        key: header.name.toNativeUtf8(),
        valueLength: utf8.encode(header.value).length,
        value: header.value.toNativeUtf8(),
      ),
  ];
  final headerStorage = calloc<core_ffi.NativePair>(nativeHeaders.length);

  try {
    for (var index = 0; index < nativeHeaders.length; index += 1) {
      (headerStorage + index).ref
        ..key.ptr = nativeHeaders[index].key.cast<Uint8>()
        ..key.len = nativeHeaders[index].nameLength
        ..value.ptr = nativeHeaders[index].value.cast<Uint8>()
        ..value.len = nativeHeaders[index].valueLength;
    }

    return run(
      nativeHeaders.isEmpty ? nullptr : headerStorage,
      nativeHeaders.length,
    );
  } finally {
    calloc.free(headerStorage);
    for (final header in nativeHeaders) {
      calloc.free(header.key);
      calloc.free(header.value);
    }
  }
}
