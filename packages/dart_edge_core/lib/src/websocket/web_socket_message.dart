import 'dart:convert';
import 'dart:typed_data';

/// The frame kind for a WebSocket message.
enum WebSocketMessageKind { text, binary }

/// One incoming or outgoing WebSocket data frame.
final class WebSocketMessage {
  const WebSocketMessage._({required this.kind, required this.bytes});

  /// Creates a text frame from a Dart string.
  factory WebSocketMessage.text(String value) {
    return WebSocketMessage._(
      kind: WebSocketMessageKind.text,
      bytes: Uint8List.fromList(utf8.encode(value)),
    );
  }

  /// Creates a binary frame from raw bytes.
  factory WebSocketMessage.binary(List<int> value) {
    return WebSocketMessage._(
      kind: WebSocketMessageKind.binary,
      bytes: Uint8List.fromList(value),
    );
  }

  /// Whether this is a text or binary frame.
  final WebSocketMessageKind kind;

  /// Raw frame bytes.
  final Uint8List bytes;

  /// Decodes this frame as UTF-8 text.
  String get text => utf8.decode(bytes);
}
