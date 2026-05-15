import 'rig_prompt_message.dart';
import 'rig_stream_event.dart';
import 'rig_token_usage.dart';

/// Lifecycle state for a Rig agent run.
enum RigAgentRunStatus {
  /// The run has been created but has not started.
  pending,

  /// The run is currently streaming.
  running,

  /// The run completed with a final answer.
  completed,

  /// The run failed.
  failed,
}

/// Collected result for one Rig agent run.
final class RigAgentRun {
  /// Creates a run snapshot.
  const RigAgentRun({
    required this.id,
    required this.prompt,
    required this.status,
    required this.startedAt,
    required this.events,
    this.completedAt,
    this.output,
    this.usage,
    this.error,
  });

  /// Client-side run ID.
  final String id;

  /// Original prompt envelope.
  final RigPrompt prompt;

  /// Current run status.
  final RigAgentRunStatus status;

  /// Run start time.
  final DateTime startedAt;

  /// Run completion time, when finished.
  final DateTime? completedAt;

  /// Stream events collected during the run.
  final List<RigStreamEvent> events;

  /// Final assistant output, when available.
  final String? output;

  /// Final token usage, when the provider reports it.
  final RigTokenUsage? usage;

  /// Error text, when failed.
  final String? error;
}
