/// Provider model configuration for direct Rig model operations.
///
/// Use this for capabilities that Rig exposes outside the agent abstraction,
/// such as transcription and image generation.
final class RigModelConfig {
  /// Creates a generic Rig model configuration.
  const RigModelConfig({
    required this.provider,
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.additionalParamsJson,
  });

  /// Creates an OpenAI or OpenAI-compatible Rig model configuration.
  const RigModelConfig.openAi({
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.additionalParamsJson,
  }) : provider = 'openai';

  /// Creates a Gemini Rig model configuration.
  const RigModelConfig.gemini({
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.additionalParamsJson,
  }) : provider = 'gemini';

  /// Rig provider identifier.
  ///
  /// Supported values are `openai` and `gemini`.
  final String provider;

  /// Provider model identifier.
  final String model;

  /// Provider API key.
  ///
  /// OpenAI keeps Rig's environment fallback when both [apiKey] and [baseUrl]
  /// are omitted. Gemini requires an explicit API key.
  final String? apiKey;

  /// Provider base URL for compatible endpoints.
  final String? baseUrl;

  /// Raw provider-specific JSON parameters merged into each request.
  final String? additionalParamsJson;
}
