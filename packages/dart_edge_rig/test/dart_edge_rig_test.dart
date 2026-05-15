import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_rig/dart_edge_rig.dart';
import 'package:dart_edge_rig/src/native/dart_edge_rig_native.dart';
import 'package:test/test.dart';

void main() {
  test('exposes native ABI version', () {
    expect(DartEdgeRigNative.abiVersion, 1);
  });

  test('validates agent config before native create', () {
    expect(
      RigAgent.open(const RigAgentConfig(provider: '', api: '', model: '')),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('builds provider-specific config values', () {
    final openAi = RigAgentConfig.openAiResponses(model: 'gpt-4o-mini');
    expect(openAi.provider, 'openai');
    expect(openAi.api, 'responses');

    final geminiDefault = RigAgentConfig.geminiInteractions(
      model: 'gemini-2.5-flash',
    );
    expect(geminiDefault.provider, 'gemini');
    expect(geminiDefault.api, 'interactions');

    final gemini = RigAgentConfig.geminiInteractions(
      model: 'gemini-2.5-flash',
      temperature: 0.2,
      maxTokens: 256,
      maxTurns: 4,
      outputSchema: const JsonSchema.object(
        properties: <String, JsonSchema>{'ok': JsonSchema.boolean()},
        required: <String>['ok'],
      ),
      geminiInteractions: const RigGeminiInteractionsConfig(
        unsafeAdditionalParamsJson: '{"thinking": {"type": "enabled"}}',
      ),
      tools: <RigTool>[
        RigTool(
          name: 'lookup',
          description: 'Looks up a value.',
          parameters: const JsonSchema.object(
            properties: <String, JsonSchema>{'id': JsonSchema.string()},
            required: <String>['id'],
          ),
          call: (arguments) => <String, Object?>{'ok': true},
        ),
      ],
    );
    expect(gemini.provider, 'gemini');
    expect(gemini.api, 'interactions');
    expect(gemini.temperature, 0.2);
    expect(gemini.maxTokens, 256);
    expect(gemini.maxTurns, 4);
    expect(gemini.outputSchema?.toJson(), containsPair('type', 'object'));
    expect(
      DartEdgeRigNative.additionalParamsJson(gemini),
      contains('thinking'),
    );
    expect(gemini.tools.single.name, 'lookup');
  });

  test('merges typed provider thinking config into additional params', () {
    final openAi = RigAgentConfig.openAiResponses(
      model: 'gpt-5.2',
      openAiResponses: const RigOpenAiResponsesConfig(
        unsafeAdditionalParamsJson: '{"store": true}',
        reasoning: RigOpenAiReasoning(
          effort: RigOpenAiReasoningEffort.high,
          summary: RigOpenAiReasoningSummary.detailed,
        ),
      ),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"store":true'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"reasoning"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"effort":"high"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"summary":"detailed"'),
    );

    final geminiInteractions = RigAgentConfig.geminiInteractions(
      model: 'gemini-3-pro',
      geminiInteractions: const RigGeminiInteractionsConfig(
        thinking: RigGeminiThinking(
          thinkingLevel: RigGeminiThinkingLevel.high,
          thinkingSummaries: RigGeminiThinkingSummaries.auto,
        ),
      ),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(geminiInteractions),
      contains('"thinking_level":"high"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(geminiInteractions),
      contains('"thinking_summaries":"auto"'),
    );

    final geminiGenerateContent = RigAgentConfig.geminiGenerateContent(
      model: 'gemini-2.5-flash',
      geminiGenerateContent: const RigGeminiGenerateContentConfig(
        thinking: RigGeminiThinking(
          thinkingBudget: 1024,
          includeThoughts: true,
        ),
      ),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(geminiGenerateContent),
      contains('"thinkingConfig"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(geminiGenerateContent),
      contains('"thinkingBudget":1024'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(geminiGenerateContent),
      contains('"includeThoughts":true'),
    );
  });

  test('merges MCP servers into provider-native tool params', () {
    final openAi = RigAgentConfig.openAiResponses(
      model: 'gpt-5.2',
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
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"type":"mcp"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"server_label":"repo"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"server_url":"https://mcp.example.com/sse"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(openAi),
      contains('"allowed_tools"'),
    );

    final gemini = RigAgentConfig.geminiInteractions(
      model: 'gemini-3-pro',
      geminiInteractions: const RigGeminiInteractionsConfig(
        unsafeAdditionalParamsJson: '{"tools":[{"type":"google_search"}]}',
        mcpServers: <RigMcpServer>[
          RigMcpServer(name: 'repo', url: 'https://mcp.example.com/sse'),
        ],
      ),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(gemini),
      contains('"type":"google_search"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(gemini),
      contains('"type":"mcp_server"'),
    );
    expect(
      DartEdgeRigNative.additionalParamsJson(gemini),
      contains('"name":"repo"'),
    );
    expect(DartEdgeRigNative.additionalParamsJson(gemini), contains('"url"'));
  });

  test('validates MCP server provider support', () {
    expect(
      RigAgent.open(
        RigAgentConfig.openAiChatCompletions(
          model: 'gpt-4o-mini',
          openAiResponses: const RigOpenAiResponsesConfig(
            mcpServers: <RigMcpServer>[
              RigMcpServer(name: 'repo', url: 'https://mcp.example.com/sse'),
            ],
          ),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      RigAgent.open(
        RigAgentConfig.geminiGenerateContent(
          model: 'gemini-2.5-flash',
          geminiInteractions: const RigGeminiInteractionsConfig(
            mcpServers: <RigMcpServer>[
              RigMcpServer(name: 'repo', url: 'https://mcp.example.com/sse'),
            ],
          ),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('validates mutually exclusive Gemini thinking controls', () {
    expect(
      RigAgent.open(
        RigAgentConfig.geminiInteractions(
          model: 'gemini-2.5-flash',
          geminiInteractions: const RigGeminiInteractionsConfig(
            thinking: RigGeminiThinking(
              thinkingBudget: 128,
              thinkingLevel: RigGeminiThinkingLevel.low,
            ),
          ),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('encodes role-tagged prompt messages in Rig prompt shape', () {
    const prompt = RigPrompt(<RigPromptMessage>[
      RigPromptMessage.system('Use terse answers.'),
      RigPromptMessage.user(<RigUserContent>[
        RigUserContent.text('Read this.'),
        RigUserContent.document(
          source: RigContentSource.string('# Notes'),
          mediaType: 'markdown',
        ),
        RigUserContent.image(
          source: RigContentSource.url('https://example.com/a.png'),
          mediaType: 'png',
          detail: RigImageDetail.low,
        ),
      ]),
    ]);

    expect(prompt.toJson(), {
      'messages': [
        {'role': 'system', 'content': 'Use terse answers.'},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Read this.'},
            {
              'type': 'document',
              'data': {'type': 'string', 'value': '# Notes'},
              'media_type': 'markdown',
            },
            {
              'type': 'image',
              'data': {'type': 'url', 'value': 'https://example.com/a.png'},
              'media_type': 'png',
              'detail': 'low',
            },
          ],
        },
      ],
    });
  });

  test('prompt result decodes JSON output', () {
    const result = RigPromptResult(output: '{"ok":true}');

    expect(result.decodeJson(), <String, Object?>{'ok': true});
  });

  test('exposes stream event model types', () {
    const events = <RigStreamEvent>[
      RigTextDelta('hello'),
      RigReasoningDelta(
        text: 'thinking',
        id: 'rs_1',
        kind: RigReasoningKind.summary,
      ),
      RigToolCallEvent(
        id: 'call_1',
        internalCallId: 'internal_1',
        name: 'lookup',
        argumentsJson: '{"id":1}',
      ),
      RigToolCallDelta(
        id: 'call_1',
        internalCallId: 'internal_1',
        argumentsDelta: '{"id"',
      ),
      RigToolResultEvent(
        internalCallId: 'internal_1',
        resultJson: '{"ok":true}',
      ),
      RigFinalResponseEvent(
        'done',
        usage: RigTokenUsage(
          inputTokens: 1,
          outputTokens: 2,
          totalTokens: 3,
          cachedInputTokens: 0,
          cacheCreationInputTokens: 0,
          reasoningTokens: 1,
        ),
      ),
    ];

    expect(events, hasLength(6));
    expect((events[1] as RigReasoningDelta).kind, RigReasoningKind.summary);
    expect((events.last as RigFinalResponseEvent).usage?.reasoningTokens, 1);
  });
}
