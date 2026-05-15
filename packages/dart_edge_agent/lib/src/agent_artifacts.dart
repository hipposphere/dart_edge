import 'dart:convert';
import 'dart:io';

/// Artifact produced by an agent run.
final class AgentArtifact {
  /// Creates an artifact descriptor.
  const AgentArtifact({
    required this.id,
    required this.runId,
    required this.kind,
    required this.path,
    required this.mediaType,
    this.metadata = const <String, Object?>{},
  });

  /// Artifact identifier.
  final String id;

  /// Run identifier.
  final String runId;

  /// Artifact kind, for example `log`, `patch`, or `report`.
  final String kind;

  /// Path where the artifact content was stored.
  final String path;

  /// Media type.
  final String mediaType;

  /// JSON-compatible metadata.
  final Map<String, Object?> metadata;
}

/// Stores agent artifacts.
abstract interface class AgentArtifactStore {
  /// Writes a text artifact.
  Future<AgentArtifact> writeText({
    required String runId,
    required String kind,
    required String name,
    required String text,
    String mediaType = 'text/plain',
    Map<String, Object?> metadata = const <String, Object?>{},
  });

  /// Writes bytes as an artifact.
  Future<AgentArtifact> writeBytes({
    required String runId,
    required String kind,
    required String name,
    required List<int> bytes,
    required String mediaType,
    Map<String, Object?> metadata = const <String, Object?>{},
  });
}

/// File-backed artifact store.
final class FileAgentArtifactStore implements AgentArtifactStore {
  /// Creates a file-backed artifact store.
  FileAgentArtifactStore(this.root);

  /// Artifact root directory.
  final Directory root;

  @override
  Future<AgentArtifact> writeText({
    required String runId,
    required String kind,
    required String name,
    required String text,
    String mediaType = 'text/plain',
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return writeBytes(
      runId: runId,
      kind: kind,
      name: name,
      bytes: utf8.encode(text),
      mediaType: mediaType,
      metadata: metadata,
    );
  }

  @override
  Future<AgentArtifact> writeBytes({
    required String runId,
    required String kind,
    required String name,
    required List<int> bytes,
    required String mediaType,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final directory = Directory(_join(root.path, runId));
    await directory.create(recursive: true);
    final path = _join(directory.path, safeName);
    await File(path).writeAsBytes(bytes);
    return AgentArtifact(
      id: '$runId:$safeName',
      runId: runId,
      kind: kind,
      path: path,
      mediaType: mediaType,
      metadata: metadata,
    );
  }
}

String _join(String left, String right) {
  if (left.endsWith(Platform.pathSeparator)) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}
