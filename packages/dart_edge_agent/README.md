# dart_edge_agent

Agent harness primitives for Dart Edge applications.

This package sits above `dart_edge_rig`. It keeps provider/model concerns in
`dart_edge_rig` and owns harness concerns such as sessions, event logs, memory,
context compaction, workspace tools, and artifacts.

## Basic Shape

```dart
import 'dart:io';

import 'package:dart_edge_agent/dart_edge_agent.dart';
import 'package:dart_edge_rig/dart_edge_rig.dart';

Future<void> main() async {
  final workspace = LocalAgentWorkspace(Directory.current);
  final agent = await RigAgent.openAiResponses(
    model: 'gpt-4o-mini',
    apiKey: Platform.environment['OPENAI_API_KEY']!,
    tools: WorkspaceRigTools.all(workspace),
  );

  try {
    final session = AgentSession(
      id: 'local',
      runner: RigAgentModelRunner(agent),
      memory: InMemoryAgentMemoryStore(),
    );

    await for (final event in session.stream(
      const RigPrompt(<RigPromptMessage>[
        RigPromptMessage.user(<RigUserContent>[
          RigUserContent.text('Inspect this package and summarize it.'),
        ]),
      ]),
    )) {
      if (event.data case AgentTextDeltaEventData(:final text)) {
        stdout.write(text);
      }
    }
  } finally {
    agent.dispose();
  }
}
```

Send text plus attachments with the same streaming API:

```dart
await for (final event in session.stream(
  RigPrompt(<RigPromptMessage>[
    RigPromptMessage.user(<RigUserContent>[
      RigUserContent.text('Summarize this markdown document.'),
      await AgentAttachment.textFile(File('notes.md')),
    ]),
  ]),
  goal: 'Summarize notes.md',
)) {
  if (event.data case AgentTextDeltaEventData(:final text)) {
    stdout.write(text);
  }
}
```

`AgentSession.stream` and `AgentSession.run` take a full `RigPrompt`.

Run the included interactive CLI example:

```bash
GEMINI_API_KEY=... dart pub -C packages/dart_edge_agent run example/basic_agent.dart
```

The example waits for your first message instead of sending a built-in prompt.
It keeps the same `AgentSession` alive across turns, so follow-up messages
continue the conversation. Set `DART_EDGE_AGENT_MODEL` to override the default
Gemini model.

## Included Primitives

- `AgentSession`: streaming-first session wrapper with a `run` collector helper.
- `AgentEventLog`: append-only event log abstraction with in-memory
  implementation.
- `AgentMemoryStore`: searchable memory abstraction with in-memory
  implementation.
- `AgentCompactor`: interface for structured context compaction.
- `AgentWorkspace`: workspace abstraction with local filesystem implementation.
- `WorkspaceRigTools`: standard file/search/shell tools backed by a workspace.
- `AgentArtifactStore`: artifact abstraction with file-backed implementation.
