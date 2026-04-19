import 'dart:async';
import 'dart:convert';

/// Accessor for incoming WebSocket messages exposed to a socket handler.
final class IncomingWebSocketMessages {
  const IncomingWebSocketMessages([Stream<String>? textMessages])
    : _textMessages = textMessages ?? const Stream<String>.empty();

  final Stream<String> _textMessages;

  /// Returns the incoming message stream as raw UTF-8 text frames.
  Stream<String> text() => _textMessages;

  /// Returns the incoming message stream decoded as JSON values of type [T].
  Stream<T> json<T>() {
    return _textMessages.map<T>((message) {
      final decoded = jsonDecode(message);
      if (decoded is T) {
        return decoded;
      }

      throw StateError(
        'Incoming WebSocket message is ${decoded.runtimeType}, not $T.',
      );
    });
  }
}
