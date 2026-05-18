import 'dart:isolate';
import 'dart:typed_data';

import 'native/dart_edge_rig_native.dart';
import 'rig_model_config.dart';
import 'rig_provider.dart';

/// OpenAI image generation model identifiers exposed by Rig.
abstract final class RigOpenAiImageModels {
  /// DALL-E 2 image generation model.
  static const dallE2 = 'dall-e-2';

  /// DALL-E 3 image generation model.
  static const dallE3 = 'dall-e-3';

  /// GPT Image 1 generation model.
  static const gptImage1 = 'gpt-image-1';

  /// GPT Image 1.5 generation model.
  static const gptImage15 = 'gpt-image-1.5';

  /// GPT Image 2 generation model.
  static const gptImage2 = 'gpt-image-2';
}

/// Image bytes returned from a Rig image generation model.
final class RigImageGenerationResult {
  /// Creates an image generation result.
  const RigImageGenerationResult({
    required this.bytes,
    this.mediaType = 'image/png',
  });

  /// Generated image bytes.
  final Uint8List bytes;

  /// Media type for [bytes].
  final String mediaType;
}

/// Direct Rig image generation model wrapper.
final class RigImageGenerationModel {
  /// Creates an image generation model from a generic Rig model config.
  const RigImageGenerationModel(this.config);

  /// Creates an OpenAI image generation model.
  RigImageGenerationModel.openAi({
    String model = RigOpenAiImageModels.gptImage2,
    String? apiKey,
    String? baseUrl,
    String? additionalParamsJson,
  }) : config = RigModelConfig.openAi(
         model: model,
         apiKey: apiKey,
         baseUrl: baseUrl,
         additionalParamsJson: additionalParamsJson,
       );

  /// Model provider configuration.
  final RigModelConfig config;

  /// Generates an image from [prompt].
  Future<RigImageGenerationResult> generate(
    String prompt, {
    int width = 1024,
    int height = 1024,
    String? additionalParamsJson,
  }) async {
    _validateConfig(config);
    if (prompt.isEmpty) {
      throw ArgumentError.value(prompt, 'prompt', 'prompt must not be empty.');
    }
    if (width <= 0) {
      throw ArgumentError.value(
        width,
        'width',
        'width must be greater than zero.',
      );
    }
    if (height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'height must be greater than zero.',
      );
    }

    final invocation = _ImageGenerationInvocation(
      config: config,
      prompt: prompt,
      width: width,
      height: height,
      additionalParamsJson: additionalParamsJson,
    );
    final bytes = await Isolate.run(invocation.run);
    return RigImageGenerationResult(bytes: bytes);
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
  if (config.provider != RigProvider.openAi.nativeName) {
    throw ArgumentError.value(
      config.provider,
      'config.provider',
      'image generation is currently exposed for OpenAI models.',
    );
  }
}

final class _ImageGenerationInvocation {
  const _ImageGenerationInvocation({
    required this.config,
    required this.prompt,
    required this.width,
    required this.height,
    required this.additionalParamsJson,
  });

  final RigModelConfig config;
  final String prompt;
  final int width;
  final int height;
  final String? additionalParamsJson;

  Uint8List run() {
    return DartEdgeRigNative.generateImage(
      config,
      prompt: prompt,
      width: width,
      height: height,
      additionalParamsJson: additionalParamsJson,
    );
  }
}
