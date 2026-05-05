import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'web_socket_message.dart';

/// Accessor for incoming WebSocket messages exposed to a socket handler.
final class IncomingWebSocketMessages {
  const IncomingWebSocketMessages([Stream<WebSocketMessage>? messages])
    : _messages = messages ?? const Stream<WebSocketMessage>.empty();

  final Stream<WebSocketMessage> _messages;

  /// Returns all incoming data frames.
  Stream<WebSocketMessage> frames() => _messages;

  /// Returns the incoming message stream as raw UTF-8 text frames.
  Stream<String> text() {
    return _messages
        .where((message) => message.kind == WebSocketMessageKind.text)
        .map((message) => message.text);
  }

  /// Returns the incoming message stream as raw binary frames.
  Stream<Uint8List> binary() {
    return _messages
        .where((message) => message.kind == WebSocketMessageKind.binary)
        .map((message) => message.bytes);
  }

  /// Returns the incoming message stream decoded as JSON values of type [T].
  Stream<T> json<T>() {
    return text().map<T>((message) {
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
