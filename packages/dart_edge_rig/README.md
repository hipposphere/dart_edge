# dart_edge_rig

Native-backed Dart bindings for [Rig](https://github.com/0xPlaygrounds/rig), packaged as a Dart Edge native asset.

The package exposes direct Dart FFI bindings over a small C ABI. Provider configuration, tools, and stream events use typed FFI structs. Rich prompt content is encoded in Rig's provider-agnostic message JSON shape before crossing the FFI boundary.

## OpenAI and compatible endpoints

```dart
import 'dart:io';

import 'package:dart_edge_rig/dart_edge_rig.dart';

Future<void> main() async {
  final apiKey = Platform.environment['OPENAI_API_KEY']!;
  final agent = await RigAgent.openAiResponses(
    model: 'gpt-4o-mini',
    apiKey: apiKey,
    preamble: 'Answer tersely.',
  );

  try {
    final result = await agent.prompt(
      const RigPrompt(<RigPromptMessage>[
        RigPromptMessage.user(<RigUserContent>[
          RigUserContent.text('What is Rig?'),
        ]),
      ]),
    );
    print(result.output);
  } finally {
    agent.dispose();
  }
}
```

When `apiKey` and `baseUrl` are both omitted, OpenAI keeps Rig's normal `OPENAI_API_KEY` and `OPENAI_BASE_URL` environment fallback. If either value is configured explicitly, pass `apiKey`; pass `baseUrl` to target an OpenAI-compatible endpoint.

Use `RigAgent.openAiChatCompletions` for Chat Completions compatible servers.

Reasoning models can be configured with typed Responses API controls:

```dart
final agent = await RigAgent.openAiResponses(
  model: 'gpt-5.2',
  apiKey: apiKey,
  openAiResponses: const RigOpenAiResponsesConfig(
    reasoning: RigOpenAiReasoning(
      effort: RigOpenAiReasoningEffort.high,
      summary: RigOpenAiReasoningSummary.detailed,
    ),
  ),
);
```

## Gemini

```dart
import 'dart:io';

import 'package:dart_edge_rig/dart_edge_rig.dart';

Future<void> main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY']!;
  final agent = await RigAgent.openGeminiInteractions(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
    preamble: 'Answer tersely.',
  );

  try {
    final result = await agent.prompt(
      const RigPrompt(<RigPromptMessage>[
        RigPromptMessage.user(<RigUserContent>[
          RigUserContent.text('What is Rig?'),
        ]),
      ]),
    );
    print(result.output);
  } finally {
    agent.dispose();
  }
}
```

`apiKey` is required; this package does not let native Rig read `GEMINI_API_KEY` implicitly. Use `RigAgent.openGeminiGenerateContent` for Gemini GenerateContent-compatible endpoints.

Gemini thinking can be configured through typed controls:

```dart
final agent = await RigAgent.openGeminiInteractions(
  model: 'gemini-3-pro',
  apiKey: apiKey,
  geminiInteractions: const RigGeminiInteractionsConfig(
    thinking: RigGeminiThinking(
      thinkingLevel: RigGeminiThinkingLevel.high,
      thinkingSummaries: RigGeminiThinkingSummaries.auto,
    ),
  ),
);
```

## Streaming

`stream` emits text, reasoning/thinking, tool-call, tool-result, and final-response events. Final responses include token usage when Rig receives it from the provider, including `reasoningTokens`.

```dart
await for (final event in agent.stream(
  const RigPrompt(<RigPromptMessage>[
    RigPromptMessage.user(<RigUserContent>[
      RigUserContent.text('Solve this carefully.'),
    ]),
  ]),
)) {
  switch (event) {
    case RigReasoningDelta(kind: RigReasoningKind.summary, :final text):
      print('summary: $text');
    case RigFinalResponseEvent(:final output, :final usage):
      print(output);
      print('reasoning tokens: ${usage?.reasoningTokens ?? 0}');
    default:
      break;
  }
}
```

## MCP Servers

OpenAI Responses and Gemini Interactions can connect to hosted MCP servers as provider-native tools:

```dart
final agent = await RigAgent.openAiResponses(
  model: 'gpt-5.2',
  apiKey: apiKey,
  openAiResponses: const RigOpenAiResponsesConfig(
    mcpServers: <RigMcpServer>[
      RigMcpServer(
        name: 'repo',
        url: 'https://mcp.example.com/sse',
        headers: <String, String>{'Authorization': 'Bearer token'},
        allowedTools: <String>['search'],
      ),
    ],
  ),
);
```

The same `RigMcpServer` config maps to Gemini Interactions `mcp_server` tools:

```dart
final agent = await RigAgent.openGeminiInteractions(
  model: 'gemini-3-pro',
  apiKey: apiKey,
  geminiInteractions: const RigGeminiInteractionsConfig(
    mcpServers: <RigMcpServer>[
      RigMcpServer(name: 'repo', url: 'https://mcp.example.com/sse'),
    ],
  ),
);
```

## Rich Prompt Content

Pass `RigPrompt` to `prompt` or `stream` for provider-native attachments:

```dart
final result = await agent.prompt(
  const RigPrompt(<RigPromptMessage>[
    RigPromptMessage.user(<RigUserContent>[
      RigUserContent.text('Summarize this file.'),
      RigUserContent.document(
        source: RigContentSource.string('# Notes'),
        mediaType: 'markdown',
      ),
    ]),
  ]),
);
```

Decode structured output from the result:

```dart
final json = result.decodeJson();
```
