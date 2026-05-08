import 'dart:convert';
import 'dart:typed_data';

import '../http.dart';
import '../web_socket.dart';

/// One outbound request emitted by a generated client.
final class DartEdgeClientRequest {
  const DartEdgeClientRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
    this.body,
  });

  final HttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;

  DartEdgeClientRequest copyWith({
    HttpMethod? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) {
    return DartEdgeClientRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }
}

/// One inbound response returned to a generated client.
final class DartEdgeClientResponse {
  const DartEdgeClientResponse({
    required this.status,
    required this.contentType,
    this.headers = const <String, String>{},
    String? body,
    List<int>? bodyBytes,
  }) : _body = body,
       _bodyBytes = bodyBytes;

  final int status;
  final String contentType;
  final Map<String, String> headers;
  final String? _body;
  final List<int>? _bodyBytes;

  /// Response body decoded as UTF-8 text.
  String get body {
    final body = _body;
    if (body != null) {
      return body;
    }
    return utf8.decode(bodyBytes, allowMalformed: true);
  }

  /// Raw response body bytes.
  Uint8List get bodyBytes {
    final bytes = _bodyBytes;
    if (bytes != null) {
      return Uint8List.fromList(bytes);
    }
    return Uint8List.fromList(utf8.encode(_body ?? ''));
  }
}

/// Transport abstraction used by generated clients.
abstract interface class DartEdgeClientTransport {
  Future<DartEdgeClientResponse> send(DartEdgeClientRequest request);
}

/// One outbound WebSocket connection request emitted by a generated client.
final class DartEdgeClientWebSocketRequest {
  const DartEdgeClientWebSocketRequest({
    required this.uri,
    this.headers = const <String, String>{},
    this.protocols = const <String>[],
  });

  final Uri uri;
  final Map<String, String> headers;
  final List<String> protocols;
}

/// Active WebSocket connection returned by a generated client.
abstract interface class DartEdgeClientWebSocket {
  Stream<WebSocketMessage> get messages;

  Future<void> sendText(String value);

  Future<void> sendBinary(List<int> value);

  Future<void> sendJson(Object? value);

  Future<void> close([int? code, String? reason]);
}

/// Transport abstraction used by generated WebSocket client methods.
abstract interface class DartEdgeClientWebSocketTransport {
  Future<DartEdgeClientWebSocket> connect(
    DartEdgeClientWebSocketRequest request,
  );
}

/// Raised when a response does not match the generated route contract.
final class DartEdgeClientResponseException implements Exception {
  const DartEdgeClientResponseException({
    required this.method,
    required this.uri,
    required this.expectedStatus,
    required this.actualStatus,
    required this.body,
  });

  final HttpMethod method;
  final Uri uri;
  final int expectedStatus;
  final int actualStatus;
  final String body;

  @override
  String toString() {
    return 'DartEdgeClientResponseException('
        'method: $method, '
        'uri: $uri, '
        'expectedStatus: $expectedStatus, '
        'actualStatus: $actualStatus, '
        'body: $body'
        ')';
  }
}
