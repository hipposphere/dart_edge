/// OpenAI Responses API reasoning effort.
enum RigOpenAiReasoningEffort {
  none('none'),
  minimal('minimal'),
  low('low'),
  medium('medium'),
  high('high'),
  xhigh('xhigh');

  const RigOpenAiReasoningEffort(this.jsonName);

  /// Provider JSON value.
  final String jsonName;
}

/// OpenAI Responses API reasoning summary level.
enum RigOpenAiReasoningSummary {
  auto('auto'),
  concise('concise'),
  detailed('detailed');

  const RigOpenAiReasoningSummary(this.jsonName);

  /// Provider JSON value.
  final String jsonName;
}

/// Typed reasoning controls for OpenAI Responses API models.
final class RigOpenAiReasoning {
  /// Creates OpenAI reasoning configuration.
  const RigOpenAiReasoning({this.effort, this.summary});

  /// Reasoning effort requested from the model.
  final RigOpenAiReasoningEffort? effort;

  /// Summary detail requested from the model.
  final RigOpenAiReasoningSummary? summary;

  /// Encodes this config for Rig's OpenAI Responses `additional_params`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (effort case final effort?) 'effort': effort.jsonName,
      if (summary case final summary?) 'summary': summary.jsonName,
    };
  }
}

/// Gemini thinking depth.
enum RigGeminiThinkingLevel {
  minimal('minimal'),
  low('low'),
  medium('medium'),
  high('high');

  const RigGeminiThinkingLevel(this.jsonName);

  /// Provider JSON value.
  final String jsonName;
}

/// Gemini Interactions API thinking summary behavior.
enum RigGeminiThinkingSummaries {
  auto('auto'),
  none('none');

  const RigGeminiThinkingSummaries(this.jsonName);

  /// Provider JSON value.
  final String jsonName;
}

/// Typed thinking controls for Gemini providers.
///
/// Gemini Generate Content uses [thinkingBudget], [thinkingLevel], and
/// [includeThoughts] under `generation_config.thinking_config`.
/// Gemini Interactions uses [thinkingLevel] and [thinkingSummaries] directly
/// under `generation_config`.
final class RigGeminiThinking {
  /// Creates Gemini thinking configuration.
  const RigGeminiThinking({
    this.thinkingBudget,
    this.thinkingLevel,
    this.includeThoughts,
    this.thinkingSummaries,
  });

  /// Token budget for Gemini 2.5 thinking models.
  final int? thinkingBudget;

  /// Thinking level for Gemini 3 models.
  final RigGeminiThinkingLevel? thinkingLevel;

  /// Whether Generate Content should include thought summaries.
  final bool? includeThoughts;

  /// Interactions API summary behavior.
  final RigGeminiThinkingSummaries? thinkingSummaries;

  /// Encodes this config for Gemini Generate Content `additional_params`.
  Map<String, Object?> toGenerateContentJson() {
    return <String, Object?>{
      'generation_config': <String, Object?>{
        'thinkingConfig': <String, Object?>{
          'thinkingBudget': ?thinkingBudget,
          'thinkingLevel': ?thinkingLevel?.jsonName,
          'includeThoughts': ?includeThoughts,
        },
      },
    };
  }

  /// Encodes this config for Gemini Interactions `additional_params`.
  Map<String, Object?> toInteractionsJson() {
    return <String, Object?>{
      'generation_config': <String, Object?>{
        'thinking_level': ?thinkingLevel?.jsonName,
        'thinking_summaries': ?thinkingSummaries?.jsonName,
      },
    };
  }
}
