import '../context/request_telemetry.dart';
import 'incoming_web_socket_messages.dart';

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
