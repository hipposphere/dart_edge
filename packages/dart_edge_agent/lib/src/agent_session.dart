import 'package:dart_edge_rig/dart_edge_rig.dart';

import 'agent_compaction.dart';
import 'agent_events.dart';
import 'agent_history.dart';
import 'agent_memory.dart';
import 'agent_model_runner.dart';
import 'agent_run.dart';

/// Stateful harness around a Rig agent.
final class AgentSession {
  /// Creates an agent session.
  AgentSession({
    required this.id,
    required this.runner,
    AgentEventLog? eventLog,
    AgentHistory? history,
    this.memory,
    this.compactor,
    this.compactedContext,
  }) : eventLog = eventLog ?? InMemoryAgentEventLog(),
       history = history?.snapshot() ?? AgentHistory();

  /// Resumes a session by replaying provider-neutral history from persisted
  /// events for [runIds].
  static Future<AgentSession> resume({
    required String id,
    required AgentModelRunner runner,
    required AgentEventLog eventLog,
    required Iterable<String> runIds,
    AgentMemoryStore? memory,
    AgentCompactor? compactor,
    CompactedContext? compactedContext,
  }) async {
    final history = AgentHistory();
    for (final runId in runIds) {
      final events = await eventLog.listRunEvents(runId);
      for (final event in events) {
        _recordHistoryData(history, event);
      }
    }

    return AgentSession(
      id: id,
      runner: runner,
      eventLog: eventLog,
      history: history,
      memory: memory,
      compactor: compactor,
      compactedContext: compactedContext,
    );
  }

  /// Session identifier.
  final String id;

  /// Model runner used by this session.
  final AgentModelRunner runner;

  /// Event log for runs in this session.
  final AgentEventLog eventLog;

  /// Provider-neutral history replayed into future runs.
  final AgentHistory history;

  /// Optional memory store.
  final AgentMemoryStore? memory;

  /// Optional context compactor.
  final AgentCompactor? compactor;

  /// Current compacted context.
  CompactedContext? compactedContext;

  /// Creates a new session for [agent] with a copy of this session's history.
  AgentSession handoffTo({
    required String id,
    required AgentModelRunner runner,
    AgentEventLog? eventLog,
    AgentMemoryStore? memory,
    AgentCompactor? compactor,
    CompactedContext? compactedContext,
  }) {
    return AgentSession(
      id: id,
      runner: runner,
      eventLog: eventLog,
      history: history.snapshot(),
      memory: memory ?? this.memory,
      compactor: compactor ?? this.compactor,
      compactedContext: compactedContext ?? this.compactedContext,
    );
  }

  /// Runs [prompt] to completion.
  ///
  /// [goal] can provide a text label for memory lookup, event logging, and
  /// compaction. If omitted, the first text item in [prompt] is used.
  Future<AgentRun> run(
    RigPrompt prompt, {
    String? goal,
    String? runId,
    int? maxTurns,
    int memoryLimit = 8,
  }) async {
    final id = runId ?? _id('agent-run');
    final startedAt = DateTime.now();
    final resolvedGoal = _resolveGoal(prompt, goal);
    String? finalOutput;
    String? errorText;

    await for (final event in stream(
      prompt,
      goal: resolvedGoal,
      runId: id,
      maxTurns: maxTurns,
      memoryLimit: memoryLimit,
    )) {
      switch (event.data) {
        case AgentFinalResponseEventData(:final output):
          finalOutput = output;
        case AgentErrorEventData(:final error):
          errorText = error;
        default:
          break;
      }
    }

    final events = await eventLog.listRunEvents(id);
    return AgentRun(
      id: id,
      sessionId: this.id,
      prompt: prompt,
      status: errorText == null
          ? AgentRunStatus.completed
          : AgentRunStatus.failed,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      events: events,
      output: finalOutput,
      error: errorText,
    );
  }

  /// Streams [prompt] through the agent session.
  ///
  /// [goal] can provide a text label for memory lookup, event logging, and
  /// compaction. If omitted, the first text item in [prompt] is used.
  ///
  /// Every yielded event has already been appended to [eventLog], so callers can
  /// render live progress while still getting durable replay.
  Stream<AgentEvent> stream(
    RigPrompt prompt, {
    String? goal,
    String? runId,
    int? maxTurns,
    int memoryLimit = 8,
  }) async* {
    final id = runId ?? _id('agent-run');
    var sequence = 0;

    Future<AgentEvent> append(AgentEventData data) async {
      final event = AgentEvent(
        id: '$id:${sequence + 1}',
        runId: id,
        sequence: ++sequence,
        timestamp: DateTime.now(),
        data: data,
      );
      await eventLog.append(event);
      return event;
    }

    final resolvedGoal = _resolveGoal(prompt, goal);
    final contextPrompt = await _promptWithContext(
      resolvedGoal,
      memoryLimit: memoryLimit,
    );
    yield await append(AgentPromptEventData(goal: resolvedGoal, content: true));
    history.addUser(
      resolvedGoal,
      metadata: const <String, Object?>{'content': true},
    );

    try {
      await for (final event in runner.stream(
        _prependContext(contextPrompt, prompt),
        maxTurns: maxTurns,
      )) {
        _recordHistoryEvent(event);
        yield await append(_eventData(event));
      }

      final events = await eventLog.listRunEvents(id);
      if (compactor != null) {
        compactedContext = await compactor!.compact(
          AgentCompactionInput(
            goal: resolvedGoal,
            events: events,
            previousContext: compactedContext,
          ),
        );
        yield await append(
          AgentCompactionEventData(summary: compactedContext?.summary),
        );
      }
    } catch (error) {
      yield await append(AgentErrorEventData(error.toString()));
    }
  }

  Future<String> _promptWithContext(
    String goal, {
    required int memoryLimit,
  }) async {
    final sections = <String>[];
    if (!history.isEmpty) {
      final rendered = history.render();
      if (rendered.isNotEmpty) {
        sections.add('Previous history:\n$rendered');
      }
    }
    if (compactedContext case final context?) {
      final rendered = context.render();
      if (rendered.isNotEmpty) {
        sections.add('Compacted context:\n$rendered');
      }
    }
    if (memory case final memoryStore?) {
      final memories = await memoryStore.search(goal, limit: memoryLimit);
      if (memories.isNotEmpty) {
        sections.add(
          'Relevant memory:\n${memories.map((memory) => '- ${memory.text}').join('\n')}',
        );
      }
    }
    sections.add('Goal:\n$goal');
    return sections.join('\n\n');
  }

  void _recordHistoryEvent(RigStreamEvent event) {
    switch (event) {
      case RigFinalResponseEvent(:final output):
        history.addAssistant(output);
      case RigToolCallEvent(:final id, :final name, :final argumentsJson):
        history.addTool(
          argumentsJson,
          name: name,
          metadata: <String, Object?>{'kind': 'call', 'id': id},
        );
      case RigToolResultEvent(:final internalCallId, :final resultJson):
        history.addTool(
          resultJson,
          metadata: <String, Object?>{
            'kind': 'result',
            'internalCallId': internalCallId,
          },
        );
      default:
        break;
    }
  }
}

void _recordHistoryData(AgentHistory history, AgentEvent event) {
  switch (event.data) {
    case AgentPromptEventData(:final goal):
      history.add(
        AgentHistoryEntry(
          role: AgentHistoryRole.user,
          content: goal,
          createdAt: event.timestamp,
          metadata: <String, Object?>{'runId': event.runId},
        ),
      );
    case AgentFinalResponseEventData(:final output):
      history.add(
        AgentHistoryEntry(
          role: AgentHistoryRole.assistant,
          content: output,
          createdAt: event.timestamp,
          metadata: <String, Object?>{'runId': event.runId},
        ),
      );
    case AgentToolCallEventData(:final id, :final name, :final argumentsJson):
      history.add(
        AgentHistoryEntry(
          role: AgentHistoryRole.tool,
          name: name,
          content: argumentsJson,
          createdAt: event.timestamp,
          metadata: <String, Object?>{
            'runId': event.runId,
            'kind': 'call',
            'id': id,
          },
        ),
      );
    case AgentToolResultEventData(:final internalCallId, :final resultJson):
      history.add(
        AgentHistoryEntry(
          role: AgentHistoryRole.tool,
          content: resultJson,
          createdAt: event.timestamp,
          metadata: <String, Object?>{
            'runId': event.runId,
            'kind': 'result',
            'internalCallId': internalCallId,
          },
        ),
      );
    default:
      break;
  }
}

AgentEventData _eventData(RigStreamEvent event) {
  return switch (event) {
    RigTextDelta(:final text) => AgentTextDeltaEventData(text),
    RigReasoningDelta(:final id, :final kind, :final text) =>
      AgentReasoningDeltaEventData(id: id, kind: kind, text: text),
    RigToolCallEvent(
      :final id,
      :final internalCallId,
      :final name,
      :final argumentsJson,
    ) =>
      AgentToolCallEventData(
        id: id,
        internalCallId: internalCallId,
        name: name,
        argumentsJson: argumentsJson,
      ),
    RigToolCallDelta(
      :final id,
      :final internalCallId,
      :final name,
      :final argumentsDelta,
    ) =>
      AgentToolCallDeltaEventData(
        id: id,
        internalCallId: internalCallId,
        name: name,
        argumentsDelta: argumentsDelta,
      ),
    RigToolResultEvent(:final internalCallId, :final resultJson) =>
      AgentToolResultEventData(
        internalCallId: internalCallId,
        resultJson: resultJson,
      ),
    RigFinalResponseEvent(:final output, :final usage) =>
      AgentFinalResponseEventData(output: output, usage: usage?.toJson()),
    _ => AgentErrorEventData('Unknown Rig stream event: $event'),
  };
}

String? _firstText(RigPrompt prompt) {
  for (final message in prompt.messages) {
    if (message case RigUserMessage(:final content)) {
      for (final item in content) {
        if (item case RigTextContent(:final text) when text.isNotEmpty) {
          return text;
        }
      }
    }
  }
  for (final message in prompt.messages) {
    if (message case RigSystemMessage(:final content) when content.isNotEmpty) {
      return content;
    }
  }
  return null;
}

String _resolveGoal(RigPrompt prompt, String? goal) {
  if (goal != null && goal.isNotEmpty) {
    return goal;
  }
  return _firstText(prompt) ?? 'Rich prompt content';
}

RigPrompt _prependContext(String contextPrompt, RigPrompt prompt) {
  return RigPrompt(<RigPromptMessage>[
    RigPromptMessage.system(contextPrompt),
    ...prompt.messages,
  ]);
}

String _id(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
