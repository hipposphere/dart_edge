/// Contract metadata for the planned WebSocket route surface.
final class WebSocketContract {
  const WebSocketContract({
    required this.path,
    required this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
  });

  /// Route path pattern, for example `/chat/<roomId>`.
  final String path;

  /// Stable identifier used in generated output and manifests.
  final String operationId;

  /// Optional short summary for documentation.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated.
  final bool deprecated;
}
