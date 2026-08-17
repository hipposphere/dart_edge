import 'dart:convert';

/// Successful response from an OpenAI-compatible transcription endpoint.
final class OpenAiAudioTranscriptionResponse {
  const OpenAiAudioTranscriptionResponse({
    required this.statusCode,
    required this.body,
    this.contentType,
    this.requestId,
  });

  final int statusCode;
  final String body;
  final String? contentType;
  final String? requestId;

  /// Decodes the response as JSON, or returns `null` for a non-JSON response.
  Object? get json {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// Convenience accessor for the common `{ "text": "..." }` response.
  String? get text => switch (json) {
    {'text': final String value} => value,
    _ => null,
  };
}
