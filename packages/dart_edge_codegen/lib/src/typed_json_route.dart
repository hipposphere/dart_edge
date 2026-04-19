import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

/// Declares the top-level HTTP metadata for a generated JSON route.
///
/// Generators can translate this annotation into a [RouteContract] and a
/// concrete [JsonRouteDefinition].
final class TypedJsonRoute {
  const TypedJsonRoute({
    required this.method,
    required this.path,
    required this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
  });

  /// The HTTP method accepted by the route.
  final HttpMethod method;

  /// The route path pattern, for example `/users/<id>`.
  final String path;

  /// A stable identifier used in generated manifests and OpenAPI output.
  final String operationId;

  /// Short human-readable summary for generated docs.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated in generated output.
  final bool deprecated;
}
