import 'dart:convert';

import 'rig_mcp.dart';
import 'rig_provider.dart';
import 'rig_reasoning_config.dart';

/// OpenAI Responses API-specific configuration.
final class RigOpenAiResponsesConfig {
  /// Creates OpenAI Responses API configuration.
  const RigOpenAiResponsesConfig({
    this.reasoning,
    this.mcpServers = const <RigMcpServer>[],
    this.unsafeAdditionalParamsJson,
  });

  /// Reasoning controls.
  final RigOpenAiReasoning? reasoning;

  /// Provider-native MCP servers.
  final List<RigMcpServer> mcpServers;

  /// Escape hatch for provider fields not modeled by this package yet.
  final String? unsafeAdditionalParamsJson;
}

/// OpenAI Chat Completions API-specific configuration.
final class RigOpenAiCompletionsConfig {
  /// Creates OpenAI Chat Completions API configuration.
  const RigOpenAiCompletionsConfig({this.unsafeAdditionalParamsJson});

  /// Escape hatch for provider fields not modeled by this package yet.
  final String? unsafeAdditionalParamsJson;
}

/// Gemini Interactions API-specific configuration.
final class RigGeminiInteractionsConfig {
  /// Creates Gemini Interactions API configuration.
  const RigGeminiInteractionsConfig({
    this.thinking,
    this.mcpServers = const <RigMcpServer>[],
    this.unsafeAdditionalParamsJson,
  });

  /// Thinking controls.
  final RigGeminiThinking? thinking;

  /// Provider-native MCP servers.
  final List<RigMcpServer> mcpServers;

  /// Escape hatch for provider fields not modeled by this package yet.
  final String? unsafeAdditionalParamsJson;
}

/// Gemini GenerateContent API-specific configuration.
final class RigGeminiGenerateContentConfig {
  /// Creates Gemini GenerateContent API configuration.
  const RigGeminiGenerateContentConfig({
    this.thinking,
    this.unsafeAdditionalParamsJson,
  });

  /// Thinking controls.
  final RigGeminiThinking? thinking;

  /// Escape hatch for provider fields not modeled by this package yet.
  final String? unsafeAdditionalParamsJson;
}

String? rigAdditionalParamsJson({
  required String provider,
  required String api,
  RigOpenAiResponsesConfig? openAiResponses,
  RigOpenAiCompletionsConfig? openAiCompletions,
  RigGeminiInteractionsConfig? geminiInteractions,
  RigGeminiGenerateContentConfig? geminiGenerateContent,
}) {
  final params = switch ((provider, api)) {
    (final provider, final api)
        when provider == RigProvider.openAi.nativeName &&
            api == RigOpenAiApi.responses.nativeName =>
      _openAiResponsesAdditionalParams(openAiResponses),
    (final provider, _) when provider == RigProvider.openAi.nativeName =>
      _openAiCompletionsAdditionalParams(openAiCompletions),
    (final provider, final api)
        when provider == RigProvider.gemini.nativeName &&
            api == RigGeminiApi.interactions.nativeName =>
      _geminiInteractionsAdditionalParams(geminiInteractions),
    (final provider, _) when provider == RigProvider.gemini.nativeName =>
      _geminiGenerateContentAdditionalParams(geminiGenerateContent),
    _ => <String, Object?>{},
  };
  return params.isEmpty ? null : jsonEncode(params);
}

Map<String, Object?> _openAiResponsesAdditionalParams(
  RigOpenAiResponsesConfig? config,
) {
  if (config == null) {
    return <String, Object?>{};
  }
  var params = _decodeUnsafeAdditionalParamsJson(
    config.unsafeAdditionalParamsJson,
  );
  if (config.reasoning case final reasoning?) {
    params = _deepMerge(params, <String, Object?>{
      'reasoning': reasoning.toJson(),
    });
  }
  if (config.mcpServers.isNotEmpty) {
    params = _appendProviderTools(
      params,
      config.mcpServers
          .map((server) => server.toOpenAiResponsesToolJson())
          .toList(),
    );
  }
  return params;
}

Map<String, Object?> _openAiCompletionsAdditionalParams(
  RigOpenAiCompletionsConfig? config,
) {
  return _decodeUnsafeAdditionalParamsJson(config?.unsafeAdditionalParamsJson);
}

Map<String, Object?> _geminiInteractionsAdditionalParams(
  RigGeminiInteractionsConfig? config,
) {
  if (config == null) {
    return <String, Object?>{};
  }
  var params = _decodeUnsafeAdditionalParamsJson(
    config.unsafeAdditionalParamsJson,
  );
  if (config.thinking case final thinking?) {
    params = _deepMerge(params, thinking.toInteractionsJson());
  }
  if (config.mcpServers.isNotEmpty) {
    params = _appendProviderTools(
      params,
      config.mcpServers
          .map((server) => server.toGeminiInteractionsToolJson())
          .toList(),
    );
  }
  return params;
}

Map<String, Object?> _geminiGenerateContentAdditionalParams(
  RigGeminiGenerateContentConfig? config,
) {
  if (config == null) {
    return <String, Object?>{};
  }
  var params = _decodeUnsafeAdditionalParamsJson(
    config.unsafeAdditionalParamsJson,
  );
  if (config.thinking case final thinking?) {
    params = _deepMerge(params, thinking.toGenerateContentJson());
  }
  return params;
}

Map<String, Object?> _decodeUnsafeAdditionalParamsJson(String? json) {
  if (json == null) {
    return <String, Object?>{};
  }
  final decoded = jsonDecode(json);
  if (decoded is! Map) {
    throw ArgumentError.value(
      json,
      'unsafeAdditionalParamsJson',
      'unsafeAdditionalParamsJson must encode a JSON object.',
    );
  }
  return decoded.cast<String, Object?>();
}

Map<String, Object?> _appendProviderTools(
  Map<String, Object?> params,
  List<Map<String, Object?>> tools,
) {
  final result = Map<String, Object?>.of(params);
  final existing = switch (result['tools']) {
    final List<Object?> values => values,
    null => <Object?>[],
    final value => throw ArgumentError.value(
      value,
      'unsafeAdditionalParamsJson.tools',
      'unsafeAdditionalParamsJson.tools must be a JSON array.',
    ),
  };
  result['tools'] = <Object?>[...existing, ...tools];
  return result;
}

Map<String, Object?> _deepMerge(
  Map<String, Object?> base,
  Map<String, Object?> update,
) {
  final result = Map<String, Object?>.of(base);
  for (final entry in update.entries) {
    final current = result[entry.key];
    final incoming = entry.value;
    if (current is Map && incoming is Map) {
      result[entry.key] = _deepMerge(
        current.cast<String, Object?>(),
        incoming.cast<String, Object?>(),
      );
    } else {
      result[entry.key] = incoming;
    }
  }
  return result;
}
