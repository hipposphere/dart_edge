import 'dart:io';

/// Result of a workspace command.
final class AgentCommandResult {
  /// Creates a command result.
  const AgentCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Process exit code.
  final int exitCode;

  /// Standard output.
  final String stdout;

  /// Standard error.
  final String stderr;

  /// JSON-compatible representation.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'exitCode': exitCode,
      'stdout': stdout,
      'stderr': stderr,
    };
  }
}

/// Workspace exposed to an agent through tools.
abstract interface class AgentWorkspace {
  /// Workspace root.
  Directory get root;

  /// Reads a text file relative to [root].
  Future<String> readText(String path);

  /// Writes a text file relative to [root].
  Future<void> writeText(String path, String content);

  /// Lists files relative to [path].
  Future<List<String>> listFiles({String path = '.', bool recursive = true});

  /// Searches text files for [query].
  Future<List<String>> searchText(String query, {String path = '.'});

  /// Runs [command] in the workspace root.
  Future<AgentCommandResult> run(
    List<String> command, {
    Duration timeout = const Duration(seconds: 60),
  });
}

/// Local filesystem workspace.
final class LocalAgentWorkspace implements AgentWorkspace {
  /// Creates a local workspace rooted at [root].
  LocalAgentWorkspace(this.root);

  @override
  final Directory root;

  @override
  Future<String> readText(String path) {
    return File(_resolve(path)).readAsString();
  }

  @override
  Future<void> writeText(String path, String content) async {
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<List<String>> listFiles({
    String path = '.',
    bool recursive = true,
  }) async {
    final directory = Directory(_resolve(path));
    if (!await directory.exists()) {
      return const <String>[];
    }
    final rootPath = root.absolute.path;
    final files = <String>[];
    await for (final entity in directory.list(recursive: recursive)) {
      if (entity is File) {
        files.add(_relative(rootPath, entity.absolute.path));
      }
    }
    files.sort();
    return files;
  }

  @override
  Future<List<String>> searchText(String query, {String path = '.'}) async {
    final matches = <String>[];
    for (final filePath in await listFiles(path: path)) {
      final file = File(_resolve(filePath));
      String content;
      try {
        content = await file.readAsString();
      } catch (_) {
        continue;
      }
      if (content.contains(query)) {
        matches.add(filePath);
      }
    }
    return matches;
  }

  @override
  Future<AgentCommandResult> run(
    List<String> command, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (command.isEmpty) {
      throw ArgumentError.value(
        command,
        'command',
        'command must not be empty',
      );
    }

    final result = await Process.run(
      command.first,
      command.skip(1).toList(growable: false),
      workingDirectory: root.absolute.path,
    ).timeout(timeout);

    return AgentCommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }

  String _resolve(String path) {
    final rootPath = root.absolute.path;
    final resolved = root.absolute.uri
        .resolve(path)
        .normalizePath()
        .toFilePath();
    if (resolved != rootPath &&
        !resolved.startsWith('$rootPath${Platform.pathSeparator}')) {
      throw ArgumentError.value(path, 'path', 'path escapes workspace root');
    }
    return resolved;
  }
}

String _relative(String rootPath, String path) {
  if (path == rootPath) {
    return '.';
  }
  if (path.startsWith('$rootPath${Platform.pathSeparator}')) {
    return path.substring(rootPath.length + 1);
  }
  return path;
}
