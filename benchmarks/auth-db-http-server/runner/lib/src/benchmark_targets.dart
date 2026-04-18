/// Runtime family used by a benchmark target.
enum BenchmarkTargetRuntime { dartAot, node }

/// Static description of one benchmark target.
final class BenchmarkTargetDefinition {
  const BenchmarkTargetDefinition({
    required this.id,
    required this.label,
    required this.directoryName,
    required this.runtime,
  });

  final String id;
  final String label;
  final String directoryName;
  final BenchmarkTargetRuntime runtime;
}

/// All benchmark targets keyed by their stable identifier.
const benchmarkTargets = <String, BenchmarkTargetDefinition>{
  'dart_edge': BenchmarkTargetDefinition(
    id: 'dart_edge',
    label: 'Dart Edge',
    directoryName: 'dart_edge',
    runtime: BenchmarkTargetRuntime.dartAot,
  ),
  'fastify': BenchmarkTargetDefinition(
    id: 'fastify',
    label: 'Fastify',
    directoryName: 'fastify',
    runtime: BenchmarkTargetRuntime.node,
  ),
};
