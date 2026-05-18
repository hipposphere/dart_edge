import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'native/dart_edge_rig_native.dart';
import 'rig_model_config.dart';
import 'rig_provider.dart';

/// OpenAI transcription model identifiers exposed by Rig.
abstract final class RigOpenAiTranscriptionModels {
  /// OpenAI Whisper transcription model.
  static const whisper1 = 'whisper-1';
}

/// Text returned from a Rig transcription model.
final class RigTranscriptionResult {
  /// Creates a transcription result.
  const RigTranscriptionResult({required this.text});

  /// Transcribed text.
  final String text;
}

/// Direct Rig transcription model wrapper.
final class RigTranscriptionModel {
  /// Creates a transcription model from a generic Rig model config.
  const RigTranscriptionModel(this.config);

  /// Creates an OpenAI transcription model.
  RigTranscriptionModel.openAi({
    String model = RigOpenAiTranscriptionModels.whisper1,
    String? apiKey,
    String? baseUrl,
    String? additionalParamsJson,
  }) : config = RigModelConfig.openAi(
         model: model,
         apiKey: apiKey,
         baseUrl: baseUrl,
         additionalParamsJson: additionalParamsJson,
       );

  /// Creates a Gemini transcription model.
  RigTranscriptionModel.gemini({
    required String model,
    String? apiKey,
    String? baseUrl,
    String? additionalParamsJson,
  }) : config = RigModelConfig.gemini(
         model: model,
         apiKey: apiKey,
         baseUrl: baseUrl,
         additionalParamsJson: additionalParamsJson,
       );

  /// Model provider configuration.
  final RigModelConfig config;

  /// Transcribes an audio file.
  Future<RigTranscriptionResult> transcribeFile(
    String path, {
    String? filename,
    String? language,
    String? prompt,
    double? temperature,
    String? additionalParamsJson,
  }) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be empty.');
    }

    final data = await File(path).readAsBytes();
    return transcribeBytes(
      data,
      filename: filename ?? _basename(path),
      language: language,
      prompt: prompt,
      temperature: temperature,
      additionalParamsJson: additionalParamsJson,
    );
  }

  /// Transcribes in-memory audio bytes.
  Future<RigTranscriptionResult> transcribeBytes(
    List<int> bytes, {
    String filename = 'audio.mp3',
    String? language,
    String? prompt,
    double? temperature,
    String? additionalParamsJson,
  }) async {
    _validateConfig(config);
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'bytes must not be empty.');
    }
    if (filename.isEmpty) {
      throw ArgumentError.value(
        filename,
        'filename',
        'filename must not be empty.',
      );
    }
    if (temperature case final value? when value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        temperature,
        'temperature',
        'temperature must be finite.',
      );
    }

    final invocation = _TranscriptionInvocation(
      config: config,
      data: Uint8List.fromList(bytes),
      filename: filename,
      language: language,
      prompt: prompt,
      temperature: temperature,
      additionalParamsJson: additionalParamsJson,
    );
    final text = await Isolate.run(invocation.run);
    return RigTranscriptionResult(text: text);
  }
}

void _validateConfig(RigModelConfig config) {
  if (config.provider.isEmpty) {
    throw ArgumentError.value(
      config.provider,
      'config.provider',
      'provider must not be empty.',
    );
  }
  if (config.model.isEmpty) {
    throw ArgumentError.value(
      config.model,
      'config.model',
      'model must not be empty.',
    );
  }
  if (config.provider != RigProvider.openAi.nativeName &&
      config.provider != RigProvider.gemini.nativeName) {
    throw ArgumentError.value(
      config.provider,
      'config.provider',
      'unsupported transcription provider.',
    );
  }
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  if (index == -1) {
    return normalized;
  }
  return normalized.substring(index + 1);
}

final class _TranscriptionInvocation {
  const _TranscriptionInvocation({
    required this.config,
    required this.data,
    required this.filename,
    required this.language,
    required this.prompt,
    required this.temperature,
    required this.additionalParamsJson,
  });

  final RigModelConfig config;
  final Uint8List data;
  final String filename;
  final String? language;
  final String? prompt;
  final double? temperature;
  final String? additionalParamsJson;

  String run() {
    return DartEdgeRigNative.transcribe(
      config,
      data,
      filename: filename,
      language: language,
      prompt: prompt,
      temperature: temperature,
      additionalParamsJson: additionalParamsJson,
    );
  }
}
