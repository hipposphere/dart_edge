import 'rig_token_usage.dart';

/// Streaming event emitted by a Rig agent run.
abstract class RigStreamEvent {
  const RigStreamEvent();
}

/// Assistant text delta.
final class RigTextDelta extends RigStreamEvent {
  const RigTextDelta(this.text);

  /// Text chunk emitted by the model.
  final String text;
}

/// Assistant reasoning or thinking delta.
final class RigReasoningDelta extends RigStreamEvent {
  const RigReasoningDelta({
    required this.text,
    this.id,
    this.kind = RigReasoningKind.delta,
  });

  /// Provider reasoning item ID, when present.
  final String? id;

  /// Reasoning content kind.
  final RigReasoningKind kind;

  /// Displayable reasoning text or summary chunk.
  final String text;
}

/// Reasoning content kind reported by Rig.
enum RigReasoningKind { text, summary, redacted, encrypted, delta }

/// Complete tool call emitted by the model.
final class RigToolCallEvent extends RigStreamEvent {
  const RigToolCallEvent({
    required this.id,
    required this.internalCallId,
    required this.name,
    required this.argumentsJson,
  });

  /// Provider tool call ID.
  final String id;

  /// Rig-generated ID used to correlate deltas and results.
  final String internalCallId;

  /// Tool name requested by the model.
  final String name;

  /// Tool arguments encoded as JSON.
  final String argumentsJson;
}

/// Partial tool call delta emitted by the provider.
final class RigToolCallDelta extends RigStreamEvent {
  const RigToolCallDelta({
    required this.id,
    required this.internalCallId,
    this.name,
    this.argumentsDelta,
  });

  /// Provider tool call ID.
  final String id;

  /// Rig-generated ID used to correlate deltas and results.
  final String internalCallId;

  /// Tool name when this delta carries a name.
  final String? name;

  /// Partial JSON arguments when this delta carries arguments.
  final String? argumentsDelta;
}

/// Tool result emitted during a multi-turn agent run.
final class RigToolResultEvent extends RigStreamEvent {
  const RigToolResultEvent({
    required this.internalCallId,
    required this.resultJson,
  });

  /// Rig-generated ID of the tool call this result belongs to.
  final String internalCallId;

  /// Tool result encoded as JSON.
  final String resultJson;
}

/// Final aggregated response for the run.
final class RigFinalResponseEvent extends RigStreamEvent {
  const RigFinalResponseEvent(this.output, {this.usage});

  /// Final assistant response text.
  final String output;

  /// Token usage for the completed run, when reported by the provider.
  final RigTokenUsage? usage;
}
