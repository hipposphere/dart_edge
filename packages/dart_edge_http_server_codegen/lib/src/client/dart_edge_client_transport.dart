import 'package:dart_edge_core/dart_edge_core.dart';

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
}

/// One inbound response returned to a generated client.
final class DartEdgeClientResponse {
  const DartEdgeClientResponse({
    required this.status,
    required this.contentType,
    this.headers = const <String, String>{},
    required this.body,
  });

  final int status;
  final String contentType;
  final Map<String, String> headers;
  final String body;
}

/// Transport abstraction used by generated clients.
abstract interface class DartEdgeClientTransport {
  Future<DartEdgeClientResponse> send(DartEdgeClientRequest request);
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
