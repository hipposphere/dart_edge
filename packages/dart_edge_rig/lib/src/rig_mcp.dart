/// Hosted MCP server exposed as a provider-native tool.
final class RigMcpServer {
  /// Creates an MCP server tool.
  const RigMcpServer({
    required this.name,
    required this.url,
    this.headers = const <String, String>{},
    this.allowedTools = const <String>[],
    this.additionalOpenAiConfig = const <String, Object?>{},
    this.additionalGeminiConfig = const <String, Object?>{},
  });

  /// Human-readable server label/name.
  ///
  /// OpenAI Responses uses this as `server_label`; Gemini Interactions uses it
  /// as `name`.
  final String name;

  /// MCP server URL.
  final String url;

  /// Headers forwarded by the provider when connecting to the MCP server.
  final Map<String, String> headers;

  /// Optional allow-list of tool names.
  final List<String> allowedTools;

  /// Extra OpenAI Responses MCP tool fields.
  final Map<String, Object?> additionalOpenAiConfig;

  /// Extra Gemini Interactions MCP tool fields.
  final Map<String, Object?> additionalGeminiConfig;

  /// Encodes this server as an OpenAI Responses hosted MCP tool.
  Map<String, Object?> toOpenAiResponsesToolJson() {
    return <String, Object?>{
      'type': 'mcp',
      'server_label': name,
      'server_url': url,
      if (headers.isNotEmpty) 'headers': headers,
      if (allowedTools.isNotEmpty) 'allowed_tools': allowedTools,
      ...additionalOpenAiConfig,
    };
  }

  /// Encodes this server as a Gemini Interactions MCP server tool.
  Map<String, Object?> toGeminiInteractionsToolJson() {
    return <String, Object?>{
      'type': 'mcp_server',
      'name': name,
      'url': url,
      if (headers.isNotEmpty) 'headers': headers,
      if (allowedTools.isNotEmpty)
        'allowed_tools': <String, Object?>{'tools': allowedTools},
      ...additionalGeminiConfig,
    };
  }
}
