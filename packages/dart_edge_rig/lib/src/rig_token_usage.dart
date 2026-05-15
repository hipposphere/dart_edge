import 'dart:convert';

/// Token usage reported by Rig for a completed streamed run.
final class RigTokenUsage {
  /// Creates token usage metadata.
  const RigTokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.cachedInputTokens,
    required this.cacheCreationInputTokens,
    required this.reasoningTokens,
  });

  /// Decodes token usage from Rig JSON.
  factory RigTokenUsage.fromJson(Map<String, Object?> json) {
    return RigTokenUsage(
      inputTokens: _readInt(json, 'input_tokens'),
      outputTokens: _readInt(json, 'output_tokens'),
      totalTokens: _readInt(json, 'total_tokens'),
      cachedInputTokens: _readInt(json, 'cached_input_tokens'),
      cacheCreationInputTokens: _readInt(json, 'cache_creation_input_tokens'),
      reasoningTokens: _readInt(json, 'reasoning_tokens'),
    );
  }

  /// Decodes token usage from Rig JSON text.
  factory RigTokenUsage.fromJsonString(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw FormatException('Rig token usage must be a JSON object.', json);
    }
    return RigTokenUsage.fromJson(decoded.cast<String, Object?>());
  }

  /// The number of input tokens.
  final int inputTokens;

  /// The number of output tokens.
  final int outputTokens;

  /// The total token count.
  final int totalTokens;

  /// Input tokens read from provider-managed cache.
  final int cachedInputTokens;

  /// Input tokens written to provider-managed cache.
  final int cacheCreationInputTokens;

  /// Internal reasoning/thinking tokens, when reported by the provider.
  final int reasoningTokens;

  /// Encodes token usage as JSON.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'total_tokens': totalTokens,
      'cached_input_tokens': cachedInputTokens,
      'cache_creation_input_tokens': cacheCreationInputTokens,
      'reasoning_tokens': reasoningTokens,
    };
  }

  static int _readInt(Map<String, Object?> json, String key) {
    return switch (json[key]) {
      final int value => value,
      final num value => value.toInt(),
      _ => 0,
    };
  }
}
