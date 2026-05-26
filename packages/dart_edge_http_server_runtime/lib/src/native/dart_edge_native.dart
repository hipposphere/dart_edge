import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;
import 'package:ffi/ffi.dart';

import '../runtime/native_request.dart';
import '../runtime/transport_request.dart';
import 'generated_bindings.dart' as gen;
import 'native_transport_request.dart';
import 'native_transport_web_socket.dart';
import 'native_transport_web_transport.dart';

typedef NativeTransportEvent = Void Function(Int32, Int64);

final class NativeServerStartResult {
  const NativeServerStartResult({required this.serverId, required this.port});

  final int serverId;
  final int port;
}

final class NativeTransportRequestLease {
  NativeTransportRequestLease._({
    required this.request,
    required this.nativeRequest,
    required this._requestPtr,
    this.releaseNativeBody,
  });

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
  static bool get hasBundledRuntime => abiVersion >= 13;

  /// Starts the native HTTP server.
  static NativeServerStartResult startServer(
    String host,
    int port, {
    required int workers,
    required String routesJson,
    required String middlewaresJson,
    required Pointer<NativeFunction<NativeTransportEvent>> callback,
  }) {
    final hostPtr = host.toNativeUtf8();
    final routesJsonPtr = routesJson.toNativeUtf8();
    final middlewaresJsonPtr = middlewaresJson.toNativeUtf8();

    try {
      final result = gen.dart_edge_http_server_runtime_start_server(
        hostPtr.cast<Char>(),
        port,
        workers,
        routesJsonPtr.cast<Char>(),
        middlewaresJsonPtr.cast<Char>(),
        callback,
      );
      if (result <= 0) {
        return const NativeServerStartResult(serverId: -1, port: -1);
      }
      return NativeServerStartResult(
        serverId: result >> 16,
        port: result & 0xffff,
      );
    } finally {
      calloc.free(hostPtr);
      calloc.free(routesJsonPtr);
      calloc.free(middlewaresJsonPtr);
    }
  }

  /// Stops the active native server, if one is running.
  static void stopServer() {
    gen.dart_edge_http_server_runtime_stop_server();
  }

  /// Stops one active native server by native server id.
  static void stopServerById(int serverId) {
    gen.dart_edge_http_server_runtime_stop_server_by_id(serverId);
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
    required List<int> body,
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    final contentTypePtr = contentType.toNativeUtf8();
    final bytes = Uint8List.fromList(body);
    final bodyPtr = calloc<Uint8>(bytes.length);
    final nativeBytesPtr = calloc<core_ffi.NativeBytes>();
    try {
      bodyPtr.asTypedList(bytes.length).setAll(0, bytes);
      nativeBytesPtr.ref
        ..ptr = bodyPtr
        ..len = bytes.length;
      return _withNativeHeaders(
        headers,
        (headerStorage, headerCount) =>
            gen.dart_edge_http_server_runtime_send_response(
              requestId,
              status,
              contentTypePtr.cast<Char>(),
              nativeBytesPtr.ref,
              headerCount,
              headerStorage,
            ),
      );
    } finally {
      calloc.free(contentTypePtr);
      calloc.free(nativeBytesPtr);
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

  /// Accepts a pending WebTransport CONNECT request.
  static bool acceptWebTransport(
    int requestId, {
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    return _withNativeHeaders(
      headers,
      (headerStorage, headerCount) =>
          gen.dart_edge_http_server_runtime_accept_web_transport(
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

  /// Reads one queued WebSocket message from the native runtime.
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

  /// Reads one queued WebTransport connection open event from the native runtime.
  static NativeWebTransportConnection? takeWebTransportConnection(
    int sessionId,
  ) {
    final connectionPtr = gen
        .dart_edge_http_server_runtime_take_web_transport_connection(sessionId);
    if (connectionPtr == nullptr) {
      return null;
    }

    try {
      return decodeNativeWebTransportConnection(connectionPtr);
    } finally {
      gen.dart_edge_http_server_runtime_free_web_transport_connection(
        connectionPtr,
      );
    }
  }

  /// Reads one queued WebTransport datagram from the native runtime.
  static NativeWebTransportDatagram? takeWebTransportDatagram(int sessionId) {
    final datagramPtr = gen
        .dart_edge_http_server_runtime_take_web_transport_datagram(sessionId);
    if (datagramPtr == nullptr) {
      return null;
    }

    try {
      return decodeNativeWebTransportDatagram(datagramPtr);
    } finally {
      gen.dart_edge_http_server_runtime_free_web_transport_datagram(
        datagramPtr,
      );
    }
  }

  /// Reads one queued WebTransport reliable stream payload from the native runtime.
  static NativeWebTransportStream? takeWebTransportStream(int sessionId) {
    final streamPtr = gen
        .dart_edge_http_server_runtime_take_web_transport_stream(sessionId);
    if (streamPtr == nullptr) {
      return null;
    }

    try {
      return decodeNativeWebTransportStream(streamPtr);
    } finally {
      gen.dart_edge_http_server_runtime_free_web_transport_stream(streamPtr);
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

  /// Sends a binary frame over an active WebSocket session.
  static bool webSocketSendBinary(int sessionId, List<int> body) {
    final bytes = Uint8List.fromList(body);
    final bodyPtr = calloc<Uint8>(bytes.length);
    final nativeBytesPtr = calloc<core_ffi.NativeBytes>();
    try {
      bodyPtr.asTypedList(bytes.length).setAll(0, bytes);
      nativeBytesPtr.ref
        ..ptr = bodyPtr
        ..len = bytes.length;
      return gen.dart_edge_http_server_runtime_web_socket_send_binary(
        sessionId,
        nativeBytesPtr.ref,
      );
    } finally {
      calloc.free(nativeBytesPtr);
      calloc.free(bodyPtr);
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

  /// Sends one datagram over an active WebTransport session.
  static bool webTransportSendDatagram(int sessionId, List<int> body) {
    return _withNativeBody(
      body,
      (nativeBytes) =>
          gen.dart_edge_http_server_runtime_web_transport_send_datagram(
            sessionId,
            nativeBytes,
          ),
    );
  }

  /// Sends one reliable payload over a new WebTransport stream.
  static bool webTransportSendStream(int sessionId, List<int> body) {
    return _withNativeBody(
      body,
      (nativeBytes) =>
          gen.dart_edge_http_server_runtime_web_transport_send_stream(
            sessionId,
            nativeBytes,
          ),
    );
  }

  static bool _withNativeBody(
    List<int> body,
    bool Function(core_ffi.NativeBytes body) run,
  ) {
    final bytes = Uint8List.fromList(body);
    final bodyPtr = calloc<Uint8>(bytes.length);
    final nativeBytesPtr = calloc<core_ffi.NativeBytes>();
    try {
      bodyPtr.asTypedList(bytes.length).setAll(0, bytes);
      nativeBytesPtr.ref
        ..ptr = bodyPtr
        ..len = bytes.length;
      return run(nativeBytesPtr.ref);
    } finally {
      calloc.free(nativeBytesPtr);
      calloc.free(bodyPtr);
    }
  }

  /// Closes an active WebTransport session.
  static bool webTransportClose(int sessionId, {int? code, String? reason}) {
    final reasonPtr = reason?.toNativeUtf8();
    try {
      return gen.dart_edge_http_server_runtime_web_transport_close(
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
