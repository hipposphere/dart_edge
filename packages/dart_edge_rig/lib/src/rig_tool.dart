import 'dart:async';

import 'package:dart_edge_core/dart_edge_core.dart';

/// Dart callback used to execute a Rig tool.
typedef RigToolCallback = FutureOr<Object?> Function(Object? arguments);

/// Dart-defined tool exposed to the native Rig agent.
final class RigTool {
  /// Creates a Dart-backed Rig tool.
  const RigTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.call,
  });

  /// Tool name exposed to the model.
  final String name;

  /// Human-readable tool description exposed to the model.
  final String description;

  /// JSON Schema for the tool arguments.
  final JsonSchema parameters;

  /// Callback invoked when Rig executes this tool.
  final RigToolCallback call;
}
