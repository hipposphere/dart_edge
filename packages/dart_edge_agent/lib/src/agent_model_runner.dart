import 'package:dart_edge_rig/dart_edge_rig.dart';

/// Model execution boundary used by [AgentSession].
abstract interface class AgentModelRunner {
  /// Streams model events for [prompt].
  Stream<RigStreamEvent> stream(RigPrompt prompt, {int? maxTurns});
}

/// [AgentModelRunner] backed by a native Rig agent.
final class RigAgentModelRunner implements AgentModelRunner {
  /// Creates a model runner for [agent].
  const RigAgentModelRunner(this.agent);

  /// Underlying Rig agent.
  final RigAgent agent;

  @override
  Stream<RigStreamEvent> stream(RigPrompt prompt, {int? maxTurns}) {
    return agent.stream(prompt, maxTurns: maxTurns);
  }
}
