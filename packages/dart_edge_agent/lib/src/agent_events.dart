import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_rig/dart_edge_rig.dart';

/// Current schema version for persisted agent events.
const int agentEventSchemaVersion = 1;

/// Type of event emitted by an agent run.
enum AgentEventType {
  prompt,
  textDelta,
  reasoningDelta,
  toolCall,
  toolCallDelta,
  toolResult,
  finalResponse,
  compaction,
  memory,
  artifact,
  error,
}

/// Typed payload for an agent event.
sealed class AgentEventData {
  const AgentEventData();

  /// Event type represented by this data object.
  AgentEventType get type;

  /// Encodes this data as a durable JSON-compatible payload.
  Map<String, Object?> toJson();
}

final class AgentPromptEventData extends AgentEventData {
  const AgentPromptEventData({required this.goal, this.content = false});

  final String goal;
  final bool content;

  @override
  AgentEventType get type => AgentEventType.prompt;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'goal': goal,
    if (content) 'content': true,
  };
}

final class AgentTextDeltaEventData extends AgentEventData {
  const AgentTextDeltaEventData(this.text);

  final String text;

  @override
  AgentEventType get type => AgentEventType.textDelta;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'text': text};
}

final class AgentReasoningDeltaEventData extends AgentEventData {
  const AgentReasoningDeltaEventData({
    this.id,
    required this.kind,
    required this.text,
  });

  final String? id;
  final RigReasoningKind kind;
  final String text;

  @override
  AgentEventType get type => AgentEventType.reasoningDelta;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'text': text,
  };
}

final class AgentToolCallEventData extends AgentEventData {
  const AgentToolCallEventData({
    required this.id,
    required this.internalCallId,
    required this.name,
    required this.argumentsJson,
  });

  final String id;
  final String internalCallId;
  final String name;
  final String argumentsJson;

  @override
  AgentEventType get type => AgentEventType.toolCall;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'internalCallId': internalCallId,
    'name': name,
    'argumentsJson': argumentsJson,
  };
}

final class AgentToolCallDeltaEventData extends AgentEventData {
  const AgentToolCallDeltaEventData({
    required this.id,
    required this.internalCallId,
    this.name,
    this.argumentsDelta,
  });

  final String id;
  final String internalCallId;
  final String? name;
  final String? argumentsDelta;

  @override
  AgentEventType get type => AgentEventType.toolCallDelta;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'internalCallId': internalCallId,
    'name': name,
    'argumentsDelta': argumentsDelta,
  };
}

final class AgentToolResultEventData extends AgentEventData {
  const AgentToolResultEventData({
    required this.internalCallId,
    required this.resultJson,
  });

  final String internalCallId;
  final String resultJson;

  @override
  AgentEventType get type => AgentEventType.toolResult;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'internalCallId': internalCallId,
    'resultJson': resultJson,
  };
}

final class AgentFinalResponseEventData extends AgentEventData {
  const AgentFinalResponseEventData({required this.output, this.usage});

  final String output;
  final Map<String, Object?>? usage;

  @override
  AgentEventType get type => AgentEventType.finalResponse;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'output': output,
    if (usage != null) 'usage': usage,
  };
}

final class AgentCompactionEventData extends AgentEventData {
  const AgentCompactionEventData({this.summary});

  final String? summary;

  @override
  AgentEventType get type => AgentEventType.compaction;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'summary': summary};
}

final class AgentMemoryEventData extends AgentEventData {
  const AgentMemoryEventData(this.value);

  final Map<String, Object?> value;

  @override
  AgentEventType get type => AgentEventType.memory;

  @override
  Map<String, Object?> toJson() => value;
}

final class AgentArtifactEventData extends AgentEventData {
  const AgentArtifactEventData(this.value);

  final Map<String, Object?> value;

  @override
  AgentEventType get type => AgentEventType.artifact;

  @override
  Map<String, Object?> toJson() => value;
}

final class AgentErrorEventData extends AgentEventData {
  const AgentErrorEventData(this.error);

  final String error;

  @override
  AgentEventType get type => AgentEventType.error;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'error': error};
}

/// Durable event emitted by an agent session.
final class AgentEvent {
  /// Creates an agent event.
  const AgentEvent({
    required this.id,
    required this.runId,
    required this.sequence,
    required this.timestamp,
    required this.data,
  });

  /// Event identifier.
  final String id;

  /// Run identifier this event belongs to.
  final String runId;

  /// Monotonic sequence number within the run.
  final int sequence;

  /// Event type.
  AgentEventType get type => data.type;

  /// Event creation time.
  final DateTime timestamp;

  /// Typed event data.
  final AgentEventData data;

  /// JSON-compatible event payload.
  Map<String, Object?> toJsonPayload() => data.toJson();

  /// JSON-compatible durable event representation.
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': agentEventSchemaVersion,
    'id': id,
    'runId': runId,
    'sequence': sequence,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'data': data.toJson(),
  };

  /// Decodes a persisted agent event.
  factory AgentEvent.fromJson(Map<String, Object?> json) {
    final schemaVersion = _int(json, 'schemaVersion');
    if (schemaVersion != agentEventSchemaVersion) {
      throw FormatException(
        'Unsupported agent event schema version $schemaVersion.',
      );
    }

    final type = _eventType(_string(json, 'type'));
    return AgentEvent(
      id: _string(json, 'id'),
      runId: _string(json, 'runId'),
      sequence: _int(json, 'sequence'),
      timestamp: DateTime.parse(_string(json, 'timestamp')),
      data: _eventDataFromJson(type, _object(json, 'data')),
    );
  }
}

/// Append-only store for agent run events.
abstract interface class AgentEventLog {
  /// Appends [event].
  Future<void> append(AgentEvent event);

  /// Lists events for [runId] in sequence order.
  Future<List<AgentEvent>> listRunEvents(String runId);
}

/// In-memory event log for local runs and tests.
final class InMemoryAgentEventLog implements AgentEventLog {
  final _events = <AgentEvent>[];

  @override
  Future<void> append(AgentEvent event) async {
    _events.add(event);
  }

  @override
  Future<List<AgentEvent>> listRunEvents(String runId) async {
    return [
      for (final event in _events)
        if (event.runId == runId) event,
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
  }
}

/// JSONL-backed event log.
///
/// Each run is stored in a separate schema-versioned JSON Lines file.
final class FileAgentEventLog implements AgentEventLog {
  /// Creates a file-backed event log rooted at [root].
  FileAgentEventLog(this.root);

  /// Event log root directory.
  final Directory root;

  @override
  Future<void> append(AgentEvent event) async {
    await root.create(recursive: true);
    final file = _runFile(event.runId);
    await file.writeAsString(
      '${jsonEncode(event.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<List<AgentEvent>> listRunEvents(String runId) async {
    final file = _runFile(runId);
    if (!await file.exists()) {
      return const <AgentEvent>[];
    }

    final events = <AgentEvent>[];
    var lineNumber = 0;
    await for (final line
        in file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      lineNumber += 1;
      if (line.trim().isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(line);
        final event = AgentEvent.fromJson(_jsonObject(decoded, 'event'));
        if (event.runId == runId) {
          events.add(event);
        }
      } on FormatException catch (error) {
        throw FormatException(
          'Invalid agent event in ${file.path}:$lineNumber: ${error.message}',
          error.source,
          error.offset,
        );
      }
    }

    events.sort((a, b) => a.sequence.compareTo(b.sequence));
    return events;
  }

  File _runFile(String runId) {
    final fileName = base64Url.encode(utf8.encode(runId));
    return File('${root.path}${Platform.pathSeparator}$fileName.jsonl');
  }
}

AgentEventData _eventDataFromJson(
  AgentEventType type,
  Map<String, Object?> json,
) {
  return switch (type) {
    AgentEventType.prompt => AgentPromptEventData(
      goal: _string(json, 'goal'),
      content: _optionalBool(json, 'content') ?? false,
    ),
    AgentEventType.textDelta => AgentTextDeltaEventData(_string(json, 'text')),
    AgentEventType.reasoningDelta => AgentReasoningDeltaEventData(
      id: _optionalString(json, 'id'),
      kind: _reasoningKind(_string(json, 'kind')),
      text: _string(json, 'text'),
    ),
    AgentEventType.toolCall => AgentToolCallEventData(
      id: _string(json, 'id'),
      internalCallId: _string(json, 'internalCallId'),
      name: _string(json, 'name'),
      argumentsJson: _string(json, 'argumentsJson'),
    ),
    AgentEventType.toolCallDelta => AgentToolCallDeltaEventData(
      id: _string(json, 'id'),
      internalCallId: _string(json, 'internalCallId'),
      name: _optionalString(json, 'name'),
      argumentsDelta: _optionalString(json, 'argumentsDelta'),
    ),
    AgentEventType.toolResult => AgentToolResultEventData(
      internalCallId: _string(json, 'internalCallId'),
      resultJson: _string(json, 'resultJson'),
    ),
    AgentEventType.finalResponse => AgentFinalResponseEventData(
      output: _string(json, 'output'),
      usage: _optionalObject(json, 'usage'),
    ),
    AgentEventType.compaction => AgentCompactionEventData(
      summary: _optionalString(json, 'summary'),
    ),
    AgentEventType.memory => AgentMemoryEventData(json),
    AgentEventType.artifact => AgentArtifactEventData(json),
    AgentEventType.error => AgentErrorEventData(_string(json, 'error')),
  };
}

AgentEventType _eventType(String value) {
  for (final type in AgentEventType.values) {
    if (type.name == value) {
      return type;
    }
  }
  throw FormatException('Unknown agent event type `$value`.');
}

RigReasoningKind _reasoningKind(String value) {
  for (final kind in RigReasoningKind.values) {
    if (kind.name == value) {
      return kind;
    }
  }
  throw FormatException('Unknown reasoning kind `$value`.');
}

Map<String, Object?> _object(Map<String, Object?> json, String key) {
  return _jsonObject(json[key], key);
}

Map<String, Object?>? _optionalObject(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return _jsonObject(value, key);
}

Map<String, Object?> _jsonObject(Object? value, String name) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  throw FormatException('Expected `$name` to be a JSON object.');
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected `$key` to be a string.');
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Expected `$key` to be a string.');
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected `$key` to be an integer.');
}

bool? _optionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected `$key` to be a boolean.');
}
