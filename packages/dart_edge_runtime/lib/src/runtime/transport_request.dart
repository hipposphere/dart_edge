import 'dart:typed_data';

/// Encoded request body kind received from the native transport.
enum TransportRequestBodyKind { none, text, json }

/// Low-level request passed from the native transport runtime into Dart.
///
/// Most application code should work with [RequestContext] instead of this
/// transport-facing representation.
final class TransportRequest {
  TransportRequest({
    required this.routeId,
    required this.pathParams,
    required this.query,
    required this.headers,
    this.bodyBytes,
    this.bodyKind = TransportRequestBodyKind.none,
  });

  /// Runtime route identifier resolved by the native router.
  final String routeId;

  /// Raw path parameter values.
  final Map<String, String> pathParams;

  /// Raw query parameters.
  final Map<String, String> query;

  /// Raw request headers.
  final Map<String, String> headers;

  /// Raw request body bytes, if present.
  final Uint8List? bodyBytes;

  /// Body kind advertised by the native transport.
  final TransportRequestBodyKind bodyKind;
}
