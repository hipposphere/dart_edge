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
    );
  }
}
