import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_rig/dart_edge_rig.dart';

import 'agent_workspace.dart';

/// Creates Dart-backed Rig tools for an [AgentWorkspace].
final class WorkspaceRigTools {
  const WorkspaceRigTools._();

  /// Builds the standard workspace tool set.
  static List<RigTool> all(AgentWorkspace workspace) {
    return <RigTool>[
      readFile(workspace),
      writeFile(workspace),
      listFiles(workspace),
      searchFiles(workspace),
      runCommand(workspace),
    ];
  }

  /// Reads a file.
  static RigTool readFile(AgentWorkspace workspace) {
    return RigTool(
      name: 'read_file',
      description: 'Read a UTF-8 text file from the workspace.',
      parameters: const JsonSchema.object(
        properties: <String, JsonSchema>{'path': JsonSchema.string()},
        required: <String>['path'],
        additionalProperties: false,
      ),
      call: (arguments) async {
        final args = _objectArgs(arguments);
        return <String, Object?>{
          'content': await workspace.readText(args.string('path')),
        };
      },
    );
  }

  /// Writes a file.
  static RigTool writeFile(AgentWorkspace workspace) {
    return RigTool(
      name: 'write_file',
      description: 'Write UTF-8 text content to a workspace file.',
      parameters: const JsonSchema.object(
        properties: <String, JsonSchema>{
          'path': JsonSchema.string(),
          'content': JsonSchema.string(),
        },
        required: <String>['path', 'content'],
        additionalProperties: false,
      ),
      call: (arguments) async {
        final args = _objectArgs(arguments);
        await workspace.writeText(args.string('path'), args.string('content'));
        return <String, Object?>{'ok': true};
      },
    );
  }

  /// Lists files.
  static RigTool listFiles(AgentWorkspace workspace) {
    return RigTool(
      name: 'list_files',
      description: 'List files in the workspace.',
      parameters: const JsonSchema.object(
        properties: <String, JsonSchema>{
          'path': JsonSchema.string(),
          'recursive': JsonSchema.boolean(),
        },
        additionalProperties: false,
      ),
      call: (arguments) async {
        final args = _objectArgs(arguments);
        return <String, Object?>{
          'files': await workspace.listFiles(
            path: args.optionalString('path') ?? '.',
            recursive: args.optionalBool('recursive') ?? true,
          ),
        };
      },
    );
  }

  /// Searches files for literal text.
  static RigTool searchFiles(AgentWorkspace workspace) {
    return RigTool(
      name: 'search_files',
      description: 'Search workspace text files for a literal query.',
      parameters: const JsonSchema.object(
        properties: <String, JsonSchema>{
          'query': JsonSchema.string(),
          'path': JsonSchema.string(),
        },
        required: <String>['query'],
        additionalProperties: false,
      ),
      call: (arguments) async {
        final args = _objectArgs(arguments);
        return <String, Object?>{
          'matches': await workspace.searchText(
            args.string('query'),
            path: args.optionalString('path') ?? '.',
          ),
        };
      },
    );
  }

  /// Runs a command in the workspace.
  static RigTool runCommand(AgentWorkspace workspace) {
    return RigTool(
      name: 'run_command',
      description:
          'Run a command in the workspace and return stdout, stderr, and exit code.',
      parameters: const JsonSchema.object(
        properties: <String, JsonSchema>{
          'command': JsonSchema.array(items: JsonSchema.string()),
          'timeoutSeconds': JsonSchema.integer(),
        },
        required: <String>['command'],
        additionalProperties: false,
      ),
      call: (arguments) async {
        final args = _objectArgs(arguments);
        final command = args.stringList('command');
        final timeoutSeconds = args.optionalInt('timeoutSeconds') ?? 60;
        final result = await workspace.run(
          command,
          timeout: Duration(seconds: timeoutSeconds),
        );
        return result.toJson();
      },
    );
  }
}

Map<String, Object?> _objectArgs(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  throw ArgumentError.value(
    value,
    'arguments',
    'tool arguments must be an object',
  );
}

extension on Map<String, Object?> {
  String string(String key) {
    final value = this[key];
    if (value is String) {
      return value;
    }
    throw ArgumentError.value(value, key, 'expected string');
  }

  String? optionalString(String key) {
    final value = this[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw ArgumentError.value(value, key, 'expected string');
  }

  bool? optionalBool(String key) {
    final value = this[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw ArgumentError.value(value, key, 'expected bool');
  }

  int? optionalInt(String key) {
    final value = this[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw ArgumentError.value(value, key, 'expected int');
  }

  List<String> stringList(String key) {
    final value = this[key];
    if (value is List) {
      return [for (final item in value) item.toString()];
    }
    throw ArgumentError.value(value, key, 'expected list');
  }
}
