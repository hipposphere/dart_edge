import 'dart:io';

import 'package:dart_edge_agent/dart_edge_agent.dart';
import 'package:test/test.dart';

void main() {
  test('agent history snapshots and renders provider-neutral entries', () {
    final history = AgentHistory()
      ..addUser('Inspect the package.')
      ..addTool(
        '{"files":["pubspec.yaml"]}',
        name: 'list_files',
        metadata: const <String, Object?>{'kind': 'result'},
      )
      ..addAssistant('The package contains an example.');

    final snapshot = history.snapshot();
    history.addUser('Continue.');

    expect(snapshot.entries, hasLength(3));
    expect(
      snapshot.render(),
      contains('[tool list_files]\n{"files":["pubspec.yaml"]}'),
    );
    expect(
      snapshot.render(limit: 1),
      '[assistant]\nThe package contains an example.',
    );
    expect(snapshot.toJson().first['role'], 'user');
  });

  test('in-memory event log returns events in sequence order', () async {
    final log = InMemoryAgentEventLog();
    await log.append(
      AgentEvent(
        id: '2',
        runId: 'run',
        sequence: 2,
        timestamp: DateTime(2026),
        data: const AgentTextDeltaEventData('b'),
      ),
    );
    await log.append(
      AgentEvent(
        id: '1',
        runId: 'run',
        sequence: 1,
        timestamp: DateTime(2026),
        data: const AgentTextDeltaEventData('a'),
      ),
    );

    final events = await log.listRunEvents('run');
    expect(events.map((event) => event.id), ['1', '2']);
  });

  test('file event log persists schema-versioned events', () async {
    final temp = await Directory.systemTemp.createTemp(
      'dart_edge_agent_event_log_',
    );
    addTearDown(() => temp.delete(recursive: true));

    final log = FileAgentEventLog(temp);
    await log.append(
      AgentEvent(
        id: 'run:1',
        runId: 'run',
        sequence: 1,
        timestamp: DateTime.utc(2026),
        data: const AgentFinalResponseEventData(
          output: 'done',
          usage: <String, Object?>{'total_tokens': 3},
        ),
      ),
    );

    final events = await log.listRunEvents('run');
    expect(events, hasLength(1));
    expect(events.single.data, isA<AgentFinalResponseEventData>());
    expect(events.single.toJson()['schemaVersion'], agentEventSchemaVersion);
  });

  test('file memory store persists and updates memories', () async {
    final temp = await Directory.systemTemp.createTemp(
      'dart_edge_agent_memory_',
    );
    addTearDown(() => temp.delete(recursive: true));

    final store = FileAgentMemoryStore(File('${temp.path}/memory.json'));
    await store.write(const AgentMemory(id: 'repo', text: 'Use dart analyze.'));
    await store.write(
      const AgentMemory(id: 'repo', text: 'Use dart test after analyze.'),
    );

    final matches = await store.search('test');
    expect(matches, hasLength(1));
    expect(matches.single.text, contains('dart test'));
  });
}
