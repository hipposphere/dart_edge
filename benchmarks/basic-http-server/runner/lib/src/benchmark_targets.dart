/// Runtime family used by a benchmark target.
enum BenchmarkTargetRuntime { dartJit, dartAot, node, python, rust }

/// Static description of one benchmark target.
final class BenchmarkTargetDefinition {
  const BenchmarkTargetDefinition({
    required this.id,
    required this.label,
    required this.directoryName,
    required this.runtime,
    this.rustBinaryName,
  });

  final String id;
  final String label;
  final String directoryName;
  final BenchmarkTargetRuntime runtime;
  final String? rustBinaryName;
}

/// All benchmark targets keyed by their stable identifier.
const benchmarkTargets = <String, BenchmarkTargetDefinition>{
  'dart_edge_http_server': BenchmarkTargetDefinition(
    id: 'dart_edge_http_server',
    label: 'Dart Edge',
    directoryName: 'dart_edge_http_server',
    runtime: BenchmarkTargetRuntime.dartAot,
  ),
  'dart_edge_jit': BenchmarkTargetDefinition(
    id: 'dart_edge_jit',
    label: 'Dart Edge (JIT)',
    directoryName: 'dart_edge_http_server',
    runtime: BenchmarkTargetRuntime.dartJit,
  ),
  'shelf_router': BenchmarkTargetDefinition(
    id: 'shelf_router',
    label: 'Shelf Router',
    directoryName: 'shelf_router',
    runtime: BenchmarkTargetRuntime.dartAot,
  ),
  'shelf_router_jit': BenchmarkTargetDefinition(
    id: 'shelf_router_jit',
    label: 'Shelf Router (JIT)',
    directoryName: 'shelf_router',
    runtime: BenchmarkTargetRuntime.dartJit,
  ),
  'express': BenchmarkTargetDefinition(
    id: 'express',
    label: 'Express',
    directoryName: 'express',
    runtime: BenchmarkTargetRuntime.node,
  ),
  'fastify': BenchmarkTargetDefinition(
    id: 'fastify',
    label: 'Fastify',
    directoryName: 'fastify',
    runtime: BenchmarkTargetRuntime.node,
  ),
  'fastapi': BenchmarkTargetDefinition(
    id: 'fastapi',
    label: 'FastAPI',
    directoryName: 'fastapi',
    runtime: BenchmarkTargetRuntime.python,
  ),
  'axum': BenchmarkTargetDefinition(
    id: 'axum',
    label: 'Axum',
    directoryName: 'axum',
    runtime: BenchmarkTargetRuntime.rust,
    rustBinaryName: 'axum_benchmark',
  ),
};
