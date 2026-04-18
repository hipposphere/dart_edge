import 'dart:async';

import 'context.dart';

/// Accessor for incoming WebSocket messages exposed to a socket handler.
final class IncomingWebSocketMessages {
  const IncomingWebSocketMessages();

  /// Returns the incoming message stream decoded as JSON values of type [T].
  Stream<T> json<T>() => Stream<T>.empty();
}

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

/// Context passed to a WebSocket route when a client connects.
final class WebSocketContext<TServices> {
  WebSocketContext({
    required this.services,
    this.messages = const IncomingWebSocketMessages(),
    this.telemetry = const RequestTelemetry(),
  });

  /// Fresh services instance for the socket connection.
  final TServices services;

  /// Incoming messages exposed as typed streams.
  final IncomingWebSocketMessages messages;

  /// Telemetry hook associated with the socket lifecycle.
  final RequestTelemetry telemetry;

  /// Sends a JSON value to the client.
  Future<void> sendJson<T>(T value) async {}
}
