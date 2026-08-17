/// Connection and safety settings for an OpenAI-compatible audio endpoint.
final class OpenAiAudioClientConfig {
  const OpenAiAudioClientConfig({
    this.baseUrl = 'https://api.openai.com',
    this.apiKey,
    this.headers = const <String, String>{},
    this.connectTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(minutes: 10),
    this.maxResponseBytes = 8 * 1024 * 1024,
    this.allowHttp = false,
  });

  /// Provider origin, with or without a trailing `/v1`.
  final String baseUrl;

  /// Optional bearer token. Local OpenAI-compatible providers may omit it.
  final String? apiKey;

  /// Additional request headers such as `OpenAI-Organization`.
  final Map<String, String> headers;

  final Duration connectTimeout;
  final Duration requestTimeout;

  /// Maximum accepted provider response size.
  final int maxResponseBytes;

  /// Allows an `http://` base URL for explicitly configured local providers.
  final bool allowHttp;
}
