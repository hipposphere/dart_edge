import 'dart:async';

/// Accessor for incoming WebSocket messages exposed to a socket handler.
final class IncomingWebSocketMessages {
  const IncomingWebSocketMessages();

  /// Returns the incoming message stream decoded as JSON values of type [T].
  Stream<T> json<T>() => Stream<T>.empty();
}
