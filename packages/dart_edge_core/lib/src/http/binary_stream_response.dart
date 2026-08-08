import 'raw_response.dart';

/// Backpressured streaming response for an encoded binary HTTP body.
final class BinaryStreamResponse {
  const BinaryStreamResponse({
    required this.body,
    required this.contentType,
    this.status = 200,
    this.contentLength,
    this.headers = const <HttpHeader>[],
  }) : assert(contentLength == null || contentLength >= 0);

  /// Chunks emitted in wire order.
  final Stream<List<int>> body;

  /// Full response content type.
  final String contentType;

  /// HTTP status code.
  final int status;

  /// Total encoded body length, when known before streaming starts.
  final int? contentLength;

  /// Extra response headers.
  final List<HttpHeader> headers;
}
