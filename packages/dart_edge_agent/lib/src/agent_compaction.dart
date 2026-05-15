import 'agent_events.dart';

/// Input passed to a context compactor.
final class AgentCompactionInput {
  /// Creates compaction input.
  const AgentCompactionInput({
    required this.goal,
    required this.events,
    this.previousContext,
  });

  /// Current run goal.
  final String goal;

  /// Events to compact.
  final List<AgentEvent> events;

  /// Previously compacted context, if any.
  final CompactedContext? previousContext;
}

/// Structured compacted context carried between runs.
final class CompactedContext {
  /// Creates compacted context.
  const CompactedContext({
    required this.summary,
    this.decisions = const <String>[],
    this.openTasks = const <String>[],
    this.modifiedFiles = const <String>[],
    this.constraints = const <String>[],
    this.warnings = const <String>[],
  });

  /// Compact summary.
  final String summary;

  /// Durable decisions.
  final List<String> decisions;

  /// Open follow-up tasks.
  final List<String> openTasks;

  /// Files known to have changed.
  final List<String> modifiedFiles;

  /// Constraints to preserve.
  final List<String> constraints;

  /// Warnings and caveats.
  final List<String> warnings;

  /// Renders the compacted context into prompt text.
  String render() {
    final sections = <String>[
      if (summary.isNotEmpty) 'Summary:\n$summary',
      if (decisions.isNotEmpty) 'Decisions:\n${_bullets(decisions)}',
      if (openTasks.isNotEmpty) 'Open tasks:\n${_bullets(openTasks)}',
      if (modifiedFiles.isNotEmpty)
        'Modified files:\n${_bullets(modifiedFiles)}',
      if (constraints.isNotEmpty) 'Constraints:\n${_bullets(constraints)}',
      if (warnings.isNotEmpty) 'Warnings:\n${_bullets(warnings)}',
    ];
    return sections.join('\n\n');
  }

  static String _bullets(List<String> values) {
    return values.map((value) => '- $value').join('\n');
  }
}

/// Context compactor.
abstract interface class AgentCompactor {
  /// Compacts old event history into structured context.
  Future<CompactedContext> compact(AgentCompactionInput input);
}
