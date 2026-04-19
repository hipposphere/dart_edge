/// Convenience options for inline `Router.websocket` handlers.
final class WebSocketOptions {
  const WebSocketOptions({
    this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
  });

  /// Optional stable identifier used in generated output and manifests.
  final String? operationId;

  /// Optional short summary for documentation.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated.
  final bool deprecated;
}
