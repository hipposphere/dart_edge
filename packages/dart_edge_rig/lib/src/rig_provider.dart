/// Rig provider supported by the native bridge.
enum RigProvider {
  /// OpenAI and OpenAI-compatible endpoints.
  openAi('openai'),

  /// Google Gemini and Gemini-compatible endpoints.
  gemini('gemini');

  const RigProvider(this.nativeName);

  /// Native configuration value passed to Rig.
  final String nativeName;
}

/// OpenAI transport API used by a Rig-backed OpenAI agent.
enum RigOpenAiApi {
  /// Use OpenAI's Responses API.
  responses('responses'),

  /// Use OpenAI's Chat Completions API.
  completions('completions');

  const RigOpenAiApi(this.nativeName);

  /// Native configuration value passed to Rig.
  final String nativeName;
}

/// Gemini transport API used by a Rig-backed Gemini agent.
enum RigGeminiApi {
  /// Use Gemini's GenerateContent API.
  generateContent('generate_content'),

  /// Use Gemini's Interactions API.
  interactions('interactions');

  const RigGeminiApi(this.nativeName);

  /// Native configuration value passed to Rig.
  final String nativeName;
}
