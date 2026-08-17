import 'open_ai_audio_transcription_response.dart';

/// A cancellable in-flight audio transcription.
final class OpenAiAudioTranscriptionOperation {
  OpenAiAudioTranscriptionOperation._(this.response, this._cancel);

  /// Completes with the provider response or a cancellation exception.
  final Future<OpenAiAudioTranscriptionResponse> response;

  final void Function() _cancel;
  var _isCancelled = false;

  bool get isCancelled => _isCancelled;

  /// Requests cancellation. Calling this more than once is safe.
  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    _cancel();
  }
}

OpenAiAudioTranscriptionOperation createOpenAiAudioTranscriptionOperation(
  Future<OpenAiAudioTranscriptionResponse> response,
  void Function() cancel,
) => OpenAiAudioTranscriptionOperation._(response, cancel);
