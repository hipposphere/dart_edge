/// Parsed result of one load-test scenario run.
final class ScenarioLoadResult {
  const ScenarioLoadResult({
    required this.operations,
    required this.errors,
    required this.operationsPerSecond,
    required this.averageLatencyMs,
    required this.p50LatencyMs,
    required this.p90LatencyMs,
    required this.p99LatencyMs,
    required this.maxLatencyMs,
    this.firstError,
  });

  final int operations;
  final int errors;
  final double operationsPerSecond;
  final double averageLatencyMs;
  final double p50LatencyMs;
  final double p90LatencyMs;
  final double p99LatencyMs;
  final double maxLatencyMs;
  final String? firstError;
}
