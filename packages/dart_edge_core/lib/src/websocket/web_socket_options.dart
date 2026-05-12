import '../http/json_schema.dart';
import '../router/route_exposure.dart';
import '../router/route_options.dart';

/// Convenience options for inline `Router.websocket` handlers.
final class WebSocketOptions {
  const WebSocketOptions({
    this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
    this.exposure = RouteExposure.all,
    this.params,
    this.paramsDecoder,
    this.query,
    this.queryDecoder,
  });

  /// Optional stable identifier used in generated output and manifests.
  final String? operationId;

  /// Optional short summary for documentation.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated.
  final bool deprecated;

  /// Generated surfaces this route should appear in.
  ///
  /// [RouteExposure.client] controls generated WebSocket client methods.
  /// [RouteExposure.openApi] is preserved for consistency with HTTP route
  /// options and future WebSocket documentation support.
  final RouteExposure exposure;

  /// Schema for decoded path parameters.
  final JsonSchema? params;

  /// Optional route-local decoder for path parameters.
  final RequestValueDecoder? paramsDecoder;

  /// Schema for decoded query parameters.
  final JsonSchema? query;

  /// Optional route-local decoder for query parameters.
  final RequestValueDecoder? queryDecoder;

  /// Returns a normalized options object suitable for runtime execution.
  WebSocketOptions normalized({String? defaultOperationId}) {
    final resolvedOperationId = operationId ?? defaultOperationId;
    if (resolvedOperationId == null) {
      throw ArgumentError.value(
        this,
        'options',
        'WebSocketOptions.operationId is required for WebSocket routes.',
      );
    }

    return WebSocketOptions(
      operationId: resolvedOperationId,
      summary: summary,
      tags: List<String>.unmodifiable(tags),
      deprecated: deprecated,
      exposure: exposure,
      params: params,
      paramsDecoder: paramsDecoder,
      query: query,
      queryDecoder: queryDecoder,
    );
  }
}
