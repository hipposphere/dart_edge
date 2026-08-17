/// Network, protocol, or non-success response from the provider.
final class OpenAiAudioClientException implements Exception {
  const OpenAiAudioClientException({
    required this.message,
    this.statusCode,
    this.body,
    this.requestId,
  });

  final String message;
  final int? statusCode;
  final String? body;
  final String? requestId;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'OpenAiAudioClientException$status: $message';
  }
}

/// The caller canceled an active transcription operation.
final class OpenAiAudioRequestCancelledException implements Exception {
  const OpenAiAudioRequestCancelledException();

  @override
  String toString() => 'OpenAiAudioRequestCancelledException';
}
