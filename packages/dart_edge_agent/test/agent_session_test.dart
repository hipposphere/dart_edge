import 'package:dart_edge_agent/dart_edge_agent.dart';
import 'package:dart_edge_rig/dart_edge_rig.dart';
import 'package:test/test.dart';

void main() {
  test('session can run against a fake model runner', () async {
    final runner = _FakeModelRunner(<RigStreamEvent>[
      const RigTextDelta('hello'),
      const RigFinalResponseEvent('hello'),
    ]);
    final prompt = const RigPrompt(<RigPromptMessage>[
      RigPromptMessage.user(<RigUserContent>[RigUserContent.text('Say hi')]),
    ]);

    final session = AgentSession(id: 'session-1', runner: runner);
    final run = await session.run(prompt, runId: 'run-1', maxTurns: 2);

    expect(run.status, AgentRunStatus.completed);
    expect(run.output, 'hello');
    expect(run.prompt, same(prompt));
    expect(runner.maxTurns, 2);

    final sentPrompt = runner.prompt;
    expect(sentPrompt, isNotNull);
    expect(sentPrompt!.messages, hasLength(2));
    expect(sentPrompt.messages.first, isA<RigSystemMessage>());
    expect(sentPrompt.messages.last, same(prompt.messages.single));
  });

  test('session resumes provider-neutral history from event log', () async {
    final log = InMemoryAgentEventLog();
    await log.append(
      AgentEvent(
        id: 'old:1',
        runId: 'old',
        sequence: 1,
        timestamp: DateTime.utc(2026),
        data: const AgentPromptEventData(goal: 'Inspect package'),
      ),
    );
    await log.append(
      AgentEvent(
        id: 'old:2',
        runId: 'old',
        sequence: 2,
        timestamp: DateTime.utc(2026),
        data: const AgentFinalResponseEventData(output: 'It is a package.'),
      ),
    );

    final runner = _FakeModelRunner(<RigStreamEvent>[
      const RigFinalResponseEvent('continued'),
    ]);
    final session = await AgentSession.resume(
      id: 'resumed',
      runner: runner,
      eventLog: log,
      runIds: const <String>['old'],
    );

    await session.run(
      const RigPrompt(<RigPromptMessage>[
        RigPromptMessage.user(<RigUserContent>[
          RigUserContent.text('Continue'),
        ]),
      ]),
      runId: 'new',
    );

    final system = runner.prompt!.messages.first as RigSystemMessage;
    expect(system.content, contains('[user]'));
    expect(system.content, contains('Inspect package'));
    expect(system.content, contains('[assistant]'));
    expect(system.content, contains('It is a package.'));
  });
}

final class _FakeModelRunner implements AgentModelRunner {
  _FakeModelRunner(this.events);

  final List<RigStreamEvent> events;

  RigPrompt? prompt;
  int? maxTurns;

  @override
  Stream<RigStreamEvent> stream(RigPrompt prompt, {int? maxTurns}) {
    this.prompt = prompt;
    this.maxTurns = maxTurns;
    return Stream<RigStreamEvent>.fromIterable(events);
  }
}
