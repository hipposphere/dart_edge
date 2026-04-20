const defaultGeminiLiveModel = 'gemini-3.1-flash-live-preview';

final class GeminiLiveConfig {
  const GeminiLiveConfig({
    required this.apiKey,
    required this.model,
    required this.voiceName,
    required this.startupJingleDuration,
    required this.initialPrompt,
    required this.systemPrompt,
  });

  final String apiKey;
  final String model;
  final String voiceName;
  final Duration startupJingleDuration;
  final String initialPrompt;
  final String systemPrompt;
}
