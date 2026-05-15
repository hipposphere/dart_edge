import 'dart:convert';
import 'dart:io';

/// Current schema version for persisted agent memory.
const int agentMemorySchemaVersion = 1;

/// Reusable memory item for future agent runs.
final class AgentMemory {
  /// Creates an agent memory.
  const AgentMemory({
    required this.id,
    required this.text,
    this.metadata = const <String, Object?>{},
  });

  /// Memory identifier.
  final String id;

  /// Memory text.
  final String text;

  /// JSON-compatible metadata.
  final Map<String, Object?> metadata;

  /// Encodes this memory as JSON-compatible data.
  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'text': text, 'metadata': metadata};
  }

  /// Decodes an agent memory from JSON-compatible data.
  factory AgentMemory.fromJson(Map<String, Object?> json) {
    return AgentMemory(
      id: _string(json, 'id'),
      text: _string(json, 'text'),
      metadata: _optionalObject(json, 'metadata'),
    );
  }
}

/// Searchable memory store.
abstract interface class AgentMemoryStore {
  /// Searches for relevant memories.
  Future<List<AgentMemory>> search(String query, {int limit = 8});

  /// Writes a memory.
  Future<void> write(AgentMemory memory);
}

/// In-memory memory store for local runs and tests.
final class InMemoryAgentMemoryStore implements AgentMemoryStore {
  final _memories = <AgentMemory>[];

  @override
  Future<List<AgentMemory>> search(String query, {int limit = 8}) async {
    final normalizedQuery = query.toLowerCase();
    final matches = [
      for (final memory in _memories)
        if (memory.text.toLowerCase().contains(normalizedQuery)) memory,
    ];
    if (matches.isEmpty) {
      return _memories.take(limit).toList(growable: false);
    }
    return matches.take(limit).toList(growable: false);
  }

  @override
  Future<void> write(AgentMemory memory) async {
    _memories.add(memory);
  }
}

/// JSON-backed memory store.
final class FileAgentMemoryStore implements AgentMemoryStore {
  /// Creates a file-backed memory store at [file].
  FileAgentMemoryStore(this.file);

  /// Memory database file.
  final File file;

  @override
  Future<List<AgentMemory>> search(String query, {int limit = 8}) async {
    final memories = await _readAll();
    final normalizedQuery = query.toLowerCase();
    final matches = [
      for (final memory in memories)
        if (memory.text.toLowerCase().contains(normalizedQuery)) memory,
    ];
    if (matches.isEmpty) {
      return memories.take(limit).toList(growable: false);
    }
    return matches.take(limit).toList(growable: false);
  }

  @override
  Future<void> write(AgentMemory memory) async {
    final memories = await _readAll();
    final index = memories.indexWhere((value) => value.id == memory.id);
    if (index < 0) {
      memories.add(memory);
    } else {
      memories[index] = memory;
    }
    await _writeAll(memories);
  }

  Future<List<AgentMemory>> _readAll() async {
    if (!await file.exists()) {
      return <AgentMemory>[];
    }

    final decoded = jsonDecode(await file.readAsString());
    final json = _jsonObject(decoded, 'memory store');
    final schemaVersion = _int(json, 'schemaVersion');
    if (schemaVersion != agentMemorySchemaVersion) {
      throw FormatException(
        'Unsupported agent memory schema version $schemaVersion.',
      );
    }

    final memories = json['memories'];
    if (memories is! List) {
      throw const FormatException('Expected `memories` to be a JSON array.');
    }
    return [
      for (final memory in memories)
        AgentMemory.fromJson(_jsonObject(memory, 'memory')),
    ];
  }

  Future<void> _writeAll(List<AgentMemory> memories) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': agentMemorySchemaVersion,
        'memories': [for (final memory in memories) memory.toJson()],
      }),
      flush: true,
    );
  }
}

Map<String, Object?> _jsonObject(Object? value, String name) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  throw FormatException('Expected `$name` to be a JSON object.');
}

Map<String, Object?> _optionalObject(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <String, Object?>{};
  }
  return _jsonObject(value, key);
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
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
