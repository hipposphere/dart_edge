import 'package:dart_edge_rig/dart_edge_rig.dart';

import 'agent_events.dart';

/// Lifecycle state for a harness run.
enum AgentRunStatus { pending, running, completed, failed }

/// Collected result of one agent run.
final class AgentRun {
  /// Creates an agent run snapshot.
  const AgentRun({
    required this.id,
    required this.sessionId,
    required this.prompt,
    required this.status,
    required this.startedAt,
    required this.events,
    this.completedAt,
    this.output,
    this.error,
  });

  /// Run identifier.
  final String id;

  /// Session identifier.
  final String sessionId;

  /// Full prompt used for the run.
  final RigPrompt prompt;

  /// Run lifecycle status.
  final AgentRunStatus status;

  /// Start time.
  final DateTime startedAt;

  /// Completion time.
  final DateTime? completedAt;

  /// Events collected for this run.
  final List<AgentEvent> events;

  /// Final assistant output.
  final String? output;

  /// Failure text.
  final String? error;
}
