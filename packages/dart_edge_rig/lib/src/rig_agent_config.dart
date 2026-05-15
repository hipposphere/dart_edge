import 'package:dart_edge_core/dart_edge_core.dart';

import 'rig_provider.dart';
import 'rig_provider_api_config.dart';
import 'rig_tool.dart';

/// Configuration for creating a native Rig agent.
///
/// This object maps to a native C struct and is intentionally provider-shaped
/// rather than JSON-shaped. Prefer provider API-specific constructors such as
/// [RigAgentConfig.openAiResponses] and [RigAgentConfig.geminiInteractions].
final class RigAgentConfig {
  /// Creates a generic Rig agent configuration.
  const RigAgentConfig({
    required this.provider,
    required this.api,
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.preamble,
    this.name,
    this.temperature,
    this.maxTokens,
    this.maxTurns,
    this.outputSchema,
    this.outputSchemaJson,
    this.openAiResponses,
    this.openAiCompletions,
    this.geminiInteractions,
    this.geminiGenerateContent,
    this.tools = const <RigTool>[],
    this.headers = const <String, String>{},
  });

  /// Creates an OpenAI Responses API Rig agent configuration.
  RigAgentConfig.openAiResponses({
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.preamble,
    this.name,
    this.temperature,
    this.maxTokens,
    this.maxTurns,
    this.outputSchema,
    this.outputSchemaJson,
    this.openAiResponses = const RigOpenAiResponsesConfig(),
    this.openAiCompletions = const RigOpenAiCompletionsConfig(),
    this.geminiInteractions,
    this.geminiGenerateContent,
    this.tools = const <RigTool>[],
    this.headers = const <String, String>{},
  }) : provider = RigProvider.openAi.nativeName,
       api = RigOpenAiApi.responses.nativeName;

  /// Creates an OpenAI Chat Completions API Rig agent configuration.
  RigAgentConfig.openAiChatCompletions({
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.preamble,
    this.name,
    this.temperature,
    this.maxTokens,
    this.maxTurns,
    this.outputSchema,
    this.outputSchemaJson,
    this.openAiResponses,
    this.openAiCompletions = const RigOpenAiCompletionsConfig(),
    this.geminiInteractions,
    this.geminiGenerateContent,
    this.tools = const <RigTool>[],
    this.headers = const <String, String>{},
  }) : provider = RigProvider.openAi.nativeName,
       api = RigOpenAiApi.completions.nativeName;

  /// Creates a Gemini Interactions API Rig agent configuration.
  RigAgentConfig.geminiInteractions({
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.preamble,
    this.name,
    this.temperature,
    this.maxTokens,
    this.maxTurns,
    this.outputSchema,
    this.outputSchemaJson,
    this.openAiResponses,
    this.openAiCompletions,
    this.geminiInteractions = const RigGeminiInteractionsConfig(),
    this.geminiGenerateContent = const RigGeminiGenerateContentConfig(),
    this.tools = const <RigTool>[],
    this.headers = const <String, String>{},
  }) : provider = RigProvider.gemini.nativeName,
       api = RigGeminiApi.interactions.nativeName;

  /// Creates a Gemini GenerateContent API Rig agent configuration.
  RigAgentConfig.geminiGenerateContent({
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.preamble,
    this.name,
    this.temperature,
    this.maxTokens,
    this.maxTurns,
    this.outputSchema,
    this.outputSchemaJson,
    this.openAiResponses,
    this.openAiCompletions,
    this.geminiInteractions,
    this.geminiGenerateContent = const RigGeminiGenerateContentConfig(),
    this.tools = const <RigTool>[],
    this.headers = const <String, String>{},
  }) : provider = RigProvider.gemini.nativeName,
       api = RigGeminiApi.generateContent.nativeName;

  /// Rig provider identifier.
  ///
  /// Supported values are `openai` and `gemini`.
  final String provider;

  /// Provider-specific completion API.
  ///
  /// For OpenAI, use `responses` or `completions`. For Gemini, `interactions`
  /// is the default; `generate_content` is available as a compatibility path.
  final String api;

  /// Provider model identifier, for example `gpt-4o-mini` or
  /// `gemini-2.5-flash`.
  final String model;

  /// Provider API key.
  ///
  /// Required for Gemini. OpenAI keeps Rig's environment fallback when both
  /// [apiKey] and [baseUrl] are omitted.
  final String? apiKey;

  /// Provider base URL for compatible endpoints.
  ///
  /// For OpenAI, omitting both [apiKey] and [baseUrl] keeps Rig's
  /// `OPENAI_API_KEY` and `OPENAI_BASE_URL` fallback. Gemini base URLs must be
  /// passed explicitly.
  final String? baseUrl;

  /// Optional system prompt configured as the Rig agent preamble.
  final String? preamble;

  /// Optional agent name used for Dart-side diagnostics and native metadata.
  final String? name;

  /// Optional model temperature.
  final double? temperature;

  /// Optional maximum output token count.
  final int? maxTokens;

  /// Default maximum additional tool-call turns for prompt and streaming runs.
  ///
  /// A value of `0` allows the first tool round-trip but prevents further
  /// back-to-back tool loops. `null` leaves Rig's provider default unchanged.
  final int? maxTurns;

  /// Optional JSON Schema used for provider-native structured output.
  final JsonSchema? outputSchema;

  /// Raw JSON Schema used for provider-native structured output.
  ///
  /// Prefer [outputSchema] for Dart Edge-owned schemas. This field is retained
  /// as an escape hatch for provider-specific or externally supplied schemas.
  final String? outputSchemaJson;

  /// OpenAI Responses API-specific configuration.
  final RigOpenAiResponsesConfig? openAiResponses;

  /// OpenAI Chat Completions API-specific configuration.
  final RigOpenAiCompletionsConfig? openAiCompletions;

  /// Gemini Interactions API-specific configuration.
  final RigGeminiInteractionsConfig? geminiInteractions;

  /// Gemini GenerateContent API-specific configuration.
  final RigGeminiGenerateContentConfig? geminiGenerateContent;

  /// Dart-backed tools exposed to the model.
  final List<RigTool> tools;

  /// Reserved provider headers.
  ///
  /// This field is included in the native struct so provider-specific header
  /// support can be added without changing the Dart model shape.
  final Map<String, String> headers;
}
