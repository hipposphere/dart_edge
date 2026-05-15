import 'dart:async';
import 'dart:isolate';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'native/dart_edge_rig_native.dart';
import 'rig_agent_config.dart';
import 'rig_agent_run.dart';
import 'rig_mcp.dart';
import 'rig_prompt_message.dart';
import 'rig_prompt_result.dart';
import 'rig_provider.dart';
import 'rig_provider_api_config.dart';
import 'rig_stream_event.dart';
import 'rig_token_usage.dart';
import 'rig_tool.dart';

/// Native-backed handle for a Rig agent.
///
/// The agent owns a native Rig agent instance and must be disposed when it is no
/// longer needed. Prompt calls run on a worker isolate so blocking native work
/// does not stop the caller's isolate event loop.
final class RigAgent {
  RigAgent._(this.config, this.name, this._nativeHandle);

  /// Configuration used to create this agent.
  final RigAgentConfig config;

  /// Agent name returned by the native Rig bridge.
  final String name;

  final int _nativeHandle;
  var _disposed = false;

  /// Creates a native Rig agent.
  static Future<RigAgent> open(RigAgentConfig config) async {
    _validateConfig(config);
    final opened = await Isolate.run(() => DartEdgeRigNative.create(config));
    return RigAgent._(config, opened.name, opened.handle);
  }

  /// Creates an OpenAI Responses API Rig agent.
  static Future<RigAgent> openAiResponses({
    required String model,
    String? apiKey,
    String? baseUrl,
    String? preamble,
    String? name,
    double? temperature,
    int? maxTokens,
    int? maxTurns,
    JsonSchema? outputSchema,
    String? outputSchemaJson,
    RigOpenAiResponsesConfig config = const RigOpenAiResponsesConfig(),
    List<RigTool> tools = const <RigTool>[],
    Map<String, String> headers = const <String, String>{},
  }) {
    return open(
      RigAgentConfig.openAiResponses(
        model: model,
        apiKey: apiKey,
        baseUrl: baseUrl,
        preamble: preamble,
        name: name,
        temperature: temperature,
        maxTokens: maxTokens,
        maxTurns: maxTurns,
        outputSchema: outputSchema,
        outputSchemaJson: outputSchemaJson,
        openAiResponses: config,
        tools: tools,
        headers: headers,
      ),
    );
  }

  /// Creates an OpenAI Chat Completions API Rig agent.
  static Future<RigAgent> openAiChatCompletions({
    required String model,
    String? apiKey,
    String? baseUrl,
    String? preamble,
    String? name,
    double? temperature,
    int? maxTokens,
    int? maxTurns,
    JsonSchema? outputSchema,
    String? outputSchemaJson,
    RigOpenAiCompletionsConfig config = const RigOpenAiCompletionsConfig(),
    List<RigTool> tools = const <RigTool>[],
    Map<String, String> headers = const <String, String>{},
  }) {
    return open(
      RigAgentConfig.openAiChatCompletions(
        model: model,
        apiKey: apiKey,
        baseUrl: baseUrl,
        preamble: preamble,
        name: name,
        temperature: temperature,
        maxTokens: maxTokens,
        maxTurns: maxTurns,
        outputSchema: outputSchema,
        outputSchemaJson: outputSchemaJson,
        openAiCompletions: config,
        tools: tools,
        headers: headers,
      ),
    );
  }

  /// Creates a Gemini Interactions API Rig agent.
  static Future<RigAgent> openGeminiInteractions({
    required String model,
    String? apiKey,
    String? baseUrl,
    String? preamble,
    String? name,
    double? temperature,
    int? maxTokens,
    int? maxTurns,
    JsonSchema? outputSchema,
    String? outputSchemaJson,
    RigGeminiInteractionsConfig config = const RigGeminiInteractionsConfig(),
    List<RigTool> tools = const <RigTool>[],
    Map<String, String> headers = const <String, String>{},
  }) {
    return open(
      RigAgentConfig.geminiInteractions(
        model: model,
        apiKey: apiKey,
        baseUrl: baseUrl,
        preamble: preamble,
        name: name,
        temperature: temperature,
        maxTokens: maxTokens,
        maxTurns: maxTurns,
        outputSchema: outputSchema,
        outputSchemaJson: outputSchemaJson,
        geminiInteractions: config,
        tools: tools,
        headers: headers,
      ),
    );
  }

  /// Creates a Gemini GenerateContent API Rig agent.
  static Future<RigAgent> openGeminiGenerateContent({
    required String model,
    String? apiKey,
    String? baseUrl,
    String? preamble,
    String? name,
    double? temperature,
    int? maxTokens,
    int? maxTurns,
    JsonSchema? outputSchema,
    String? outputSchemaJson,
    RigGeminiGenerateContentConfig config =
        const RigGeminiGenerateContentConfig(),
    List<RigTool> tools = const <RigTool>[],
    Map<String, String> headers = const <String, String>{},
  }) {
    return open(
      RigAgentConfig.geminiGenerateContent(
        model: model,
        apiKey: apiKey,
        baseUrl: baseUrl,
        preamble: preamble,
        name: name,
        temperature: temperature,
        maxTokens: maxTokens,
        maxTurns: maxTurns,
        outputSchema: outputSchema,
        outputSchemaJson: outputSchemaJson,
        geminiGenerateContent: config,
        tools: tools,
        headers: headers,
      ),
    );
  }

  /// Sends rich user content to the native Rig agent and returns model output.
  Future<RigPromptResult> prompt(RigPrompt prompt) async {
    _ensureActive();
    _validatePrompt(prompt);

    final output = await Isolate.run(
      () => DartEdgeRigNative.promptContent(_nativeHandle, prompt),
    );
    return RigPromptResult(output: output);
  }

  /// Streams [prompt] through the native Rig agent.
  ///
  /// Events include text deltas, reasoning/thinking deltas, complete tool
  /// calls, tool results, and the final aggregated response. The returned
  /// stream is single-subscription because it is backed by one native run.
  Stream<RigStreamEvent> stream(RigPrompt prompt, {int? maxTurns}) {
    _ensureActive();
    _validatePrompt(prompt);
    _validateMaxTurns(maxTurns);

    return DartEdgeRigNative.streamPromptContent(
      _nativeHandle,
      prompt,
      maxTurns: maxTurns,
      tools: config.tools,
    );
  }

  /// Runs [prompt] to completion and returns a collected run snapshot.
  ///
  /// Use [stream] when callers need live progress. This helper retains every
  /// streamed event for logging or UI replay.
  Future<RigAgentRun> run(RigPrompt prompt, {String? id, int? maxTurns}) async {
    _ensureActive();
    final runId = id ?? 'rig-run-${DateTime.now().microsecondsSinceEpoch}';
    final startedAt = DateTime.now();
    final events = <RigStreamEvent>[];
    String? finalOutput;
    RigTokenUsage? usage;

    try {
      await for (final event in stream(prompt, maxTurns: maxTurns)) {
        events.add(event);
        if (event case RigFinalResponseEvent(output: final output)) {
          finalOutput = output;
          usage = event.usage;
        }
      }

      return RigAgentRun(
        id: runId,
        prompt: prompt,
        status: RigAgentRunStatus.completed,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        events: List<RigStreamEvent>.unmodifiable(events),
        output: finalOutput,
        usage: usage,
      );
    } catch (error) {
      return RigAgentRun(
        id: runId,
        prompt: prompt,
        status: RigAgentRunStatus.failed,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        events: List<RigStreamEvent>.unmodifiable(events),
        error: error.toString(),
      );
    }
  }

  static void _validatePrompt(RigPrompt prompt) {
    if (prompt.messages.isEmpty) {
      throw ArgumentError.value(
        prompt,
        'prompt',
        'prompt messages must not be empty.',
      );
    }
    for (final message in prompt.messages) {
      switch (message) {
        case RigSystemMessage(:final content) when content.isEmpty:
          throw ArgumentError.value(
            prompt,
            'prompt',
            'system message content must not be empty.',
          );
        case RigUserMessage(:final content) when content.isEmpty:
          throw ArgumentError.value(
            prompt,
            'prompt',
            'user message content must not be empty.',
          );
        case RigAssistantMessage(:final content) when content.isEmpty:
          throw ArgumentError.value(
            prompt,
            'prompt',
            'assistant message content must not be empty.',
          );
        default:
          break;
      }
    }
  }

  static void _validateMaxTurns(int? maxTurns) {
    if (maxTurns != null && maxTurns < 0) {
      throw ArgumentError.value(
        maxTurns,
        'maxTurns',
        'maxTurns must be zero or greater.',
      );
    }
  }

  /// Releases the native Rig agent handle.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    DartEdgeRigNative.dispose(_nativeHandle);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('Rig agent has been disposed.');
    }
  }

  static void _validateConfig(RigAgentConfig config) {
    if (config.provider.isEmpty) {
      throw ArgumentError.value(
        config.provider,
        'config.provider',
        'provider must not be empty.',
      );
    }
    if (config.api.isEmpty) {
      throw ArgumentError.value(
        config.api,
        'config.api',
        'api must not be empty.',
      );
    }
    if (config.model.isEmpty) {
      throw ArgumentError.value(
        config.model,
        'config.model',
        'model must not be empty.',
      );
    }
    if (config.temperature case final temperature?) {
      if (temperature.isNaN || temperature.isInfinite) {
        throw ArgumentError.value(
          temperature,
          'config.temperature',
          'temperature must be finite.',
        );
      }
    }
    if (config.maxTokens case final maxTokens? when maxTokens <= 0) {
      throw ArgumentError.value(
        maxTokens,
        'config.maxTokens',
        'maxTokens must be greater than zero.',
      );
    }
    if (config.maxTurns case final maxTurns? when maxTurns < 0) {
      throw ArgumentError.value(
        maxTurns,
        'config.maxTurns',
        'maxTurns must be zero or greater.',
      );
    }
    if (config.provider == RigProvider.openAi.nativeName &&
        config.api != RigOpenAiApi.responses.nativeName &&
        (config.openAiResponses?.mcpServers.isNotEmpty ?? false)) {
      throw ArgumentError.value(
        config.api,
        'config.api',
        'MCP servers are only supported for OpenAI Responses API.',
      );
    }
    if (config.provider == RigProvider.gemini.nativeName &&
        config.api != RigGeminiApi.interactions.nativeName &&
        (config.geminiInteractions?.mcpServers.isNotEmpty ?? false)) {
      throw ArgumentError.value(
        config.api,
        'config.api',
        'MCP servers are only supported for Gemini Interactions API.',
      );
    }
    final List<RigMcpServer> mcpServers = switch ((
      config.provider,
      config.api,
    )) {
      (final provider, final api)
          when provider == RigProvider.openAi.nativeName &&
              api == RigOpenAiApi.responses.nativeName =>
        config.openAiResponses?.mcpServers ?? const [],
      (final provider, final api)
          when provider == RigProvider.gemini.nativeName &&
              api == RigGeminiApi.interactions.nativeName =>
        config.geminiInteractions?.mcpServers ?? const [],
      _ => const [],
    };
    for (final server in mcpServers) {
      if (server.name.isEmpty) {
        throw ArgumentError.value(
          server.name,
          'config.mcpServers.name',
          'MCP server name must not be empty.',
        );
      }
      if (server.url.isEmpty) {
        throw ArgumentError.value(
          server.url,
          'config.mcpServers.url',
          'MCP server url must not be empty.',
        );
      }
    }
    if (config.outputSchema != null && config.outputSchemaJson != null) {
      throw ArgumentError.value(
        config.outputSchemaJson,
        'config.outputSchemaJson',
        'Use either outputSchema or outputSchemaJson, not both.',
      );
    }
    for (final MapEntry(:key, :value) in config.headers.entries) {
      if (key.isEmpty) {
        throw ArgumentError.value(
          key,
          'config.headers',
          'header keys must not be empty.',
        );
      }
      if (value.isEmpty) {
        throw ArgumentError.value(
          value,
          'config.headers[$key]',
          'header values must not be empty.',
        );
      }
    }
    final toolNames = <String>{};
    for (final tool in config.tools) {
      if (tool.name.isEmpty) {
        throw ArgumentError.value(
          tool.name,
          'config.tools',
          'tool names must not be empty.',
        );
      }
      if (!toolNames.add(tool.name)) {
        throw ArgumentError.value(
          tool.name,
          'config.tools',
          'tool names must be unique.',
        );
      }
      if (tool.description.isEmpty) {
        throw ArgumentError.value(
          tool.description,
          'config.tools[${tool.name}].description',
          'tool descriptions must not be empty.',
        );
      }
    }
    final thinking = switch ((config.provider, config.api)) {
      (final provider, final api)
          when provider == RigProvider.gemini.nativeName &&
              api == RigGeminiApi.interactions.nativeName =>
        config.geminiInteractions?.thinking,
      (final provider, _) when provider == RigProvider.gemini.nativeName =>
        config.geminiGenerateContent?.thinking,
      _ => null,
    };
    if (thinking != null) {
      if (thinking.thinkingBudget case final budget? when budget < 0) {
        throw ArgumentError.value(
          budget,
          'config.gemini.thinkingBudget',
          'thinkingBudget must be zero or greater.',
        );
      }
      if (thinking.thinkingBudget != null && thinking.thinkingLevel != null) {
        throw ArgumentError.value(
          thinking,
          'config.gemini.thinking',
          'thinkingBudget and thinkingLevel are mutually exclusive.',
        );
      }
    }
  }
}
