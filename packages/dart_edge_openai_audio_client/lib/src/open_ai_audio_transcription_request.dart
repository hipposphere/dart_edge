import 'open_ai_audio_form_field.dart';

/// OpenAI-compatible `/v1/audio/transcriptions` request metadata.
final class OpenAiAudioTranscriptionRequest {
  const OpenAiAudioTranscriptionRequest({
    required this.model,
    required this.filename,
    this.contentType = 'application/octet-stream',
    this.language,
    this.prompt,
    this.responseFormat,
    this.temperature,
    this.additionalFields = const <OpenAiAudioFormField>[],
  });

  final String model;
  final String filename;
  final String contentType;
  final String? language;
  final String? prompt;
  final String? responseFormat;
  final double? temperature;

  /// Provider-specific multipart fields, including repeated fields.
  final List<OpenAiAudioFormField> additionalFields;

  List<OpenAiAudioFormField> resolvedFields() => <OpenAiAudioFormField>[
    OpenAiAudioFormField('model', model),
    if (language case final value?) OpenAiAudioFormField('language', value),
    if (prompt case final value?) OpenAiAudioFormField('prompt', value),
    if (responseFormat case final value?)
      OpenAiAudioFormField('response_format', value),
    if (temperature case final value?)
      OpenAiAudioFormField('temperature', value.toString()),
    ...additionalFields,
  ];
}
