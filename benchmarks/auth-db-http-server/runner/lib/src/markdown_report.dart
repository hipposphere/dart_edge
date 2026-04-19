import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import 'benchmark_report.dart';

/// Builds a human-readable markdown report from a benchmark run.
String buildMarkdownReport(BenchmarkReport report) {
  final buffer = StringBuffer()
    ..writeln('# Auth DB HTTP Benchmark')
    ..writeln()
    ..writeln('- Generated: `${report.generatedAt.toIso8601String()}`')
    ..writeln('- Targets: `${report.options.targets.join('`, `')}`')
    ..writeln(
      '- Scenarios: `${report.options.scenarios.map((it) => it.id).join('`, `')}`',
    )
    ..writeln(
      '- CPU cap: `${report.options.singleCore ? 'single-core (~100% total CPU)' : 'disabled'}`',
    )
    ..writeln(
      '- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.',
    )
    ..writeln(
      '- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window.${report.options.singleCore ? ' The runner also CPU-caps each server process to roughly one core.' : ''} Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.',
    )
    ..writeln();

  final byScenario = <String, List<ScenarioBenchmarkResult>>{};
  for (final result in report.results) {
    byScenario
        .putIfAbsent(result.scenarioId, () => <ScenarioBenchmarkResult>[])
        .add(result);
  }

  buffer.writeln('## Summary');

  for (final scenario in report.options.scenarios) {
    final results = byScenario[scenario.id];
    if (results == null || results.length < 2) {
      continue;
    }

    final dartEdge = results.firstWhere(
      (result) => result.targetId == 'dart_edge',
    );
    final fastify = results.firstWhere(
      (result) => result.targetId == 'fastify',
    );
    final winner = _winner(dartEdge, fastify);
    final throughputDelta = _percentDelta(
      dartEdge.operationsPerSecond,
      fastify.operationsPerSecond,
    );
    final reliabilityNote = _reliabilityNote(dartEdge, fastify);

    buffer.writeln(
      '- `${scenario.id}`: $winner on throughput; Dart Edge `${dartEdge.operationsPerSecond.toStringAsFixed(1)}` ops/s vs Fastify `${fastify.operationsPerSecond.toStringAsFixed(1)}` ops/s, p50 `${dartEdge.p50LatencyMs.toStringAsFixed(2)}` ms vs `${fastify.p50LatencyMs.toStringAsFixed(2)}` ms, peak RSS `${dartEdge.peakMemoryMb.toStringAsFixed(1)}` MB vs `${fastify.peakMemoryMb.toStringAsFixed(1)}` MB, delta `${throughputDelta.toStringAsFixed(1)}%` vs Fastify.$reliabilityNote',
    );
  }

  final errorResults = report.results
      .where((result) => result.errors > 0)
      .toList();
  if (errorResults.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Reliability')
      ..writeln();

    for (final result in errorResults) {
      buffer.writeln(
        '- `${result.targetId}` / `${result.scenarioId}`: `${result.errors}` errors during measurement. First error: `${result.firstError ?? 'n/a'}`.',
      );
    }
  }

  buffer
    ..writeln()
    ..writeln('## Results')
    ..writeln()
    ..writeln(
      'Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB',
    )
    ..writeln(
      '--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:',
    );

  for (final scenario in report.options.scenarios) {
    final results =
        byScenario[scenario.id] ?? const <ScenarioBenchmarkResult>[];
    for (final result in results) {
      buffer.writeln(
        '${result.scenarioId} | '
        '${result.targetId} | '
        '${result.operations} | '
        '${result.errors} | '
        '${result.operationsPerSecond.toStringAsFixed(1)} | '
        '${result.p50LatencyMs.toStringAsFixed(2)} | '
        '${result.p99LatencyMs.toStringAsFixed(2)} | '
        '${result.averageCpuPercent.toStringAsFixed(1)} | '
        '${result.peakCpuPercent.toStringAsFixed(1)} | '
        '${result.averageMemoryMb.toStringAsFixed(1)} | '
        '${result.peakMemoryMb.toStringAsFixed(1)}',
      );
    }
  }

  return buffer.toString();
}

String _winner(
  ScenarioBenchmarkResult dartEdge,
  ScenarioBenchmarkResult fastify,
) {
  if (dartEdge.errors == 0 && fastify.errors > 0) {
    return 'Dart Edge wins because Fastify produced errors';
  }
  if (fastify.errors == 0 && dartEdge.errors > 0) {
    return 'Fastify wins because Dart Edge produced errors';
  }
  if (dartEdge.operationsPerSecond > fastify.operationsPerSecond) {
    return 'Dart Edge wins';
  }
  if (fastify.operationsPerSecond > dartEdge.operationsPerSecond) {
    return 'Fastify wins';
  }
  return 'near tie';
}

double _percentDelta(double value, double baseline) {
  if (baseline == 0) {
    return 0;
  }
  return ((value - baseline) / baseline) * 100;
}

String _reliabilityNote(
  ScenarioBenchmarkResult dartEdge,
  ScenarioBenchmarkResult fastify,
) {
  if (dartEdge.errors == 0 && fastify.errors == 0) {
    return '';
  }

  return ' Reliability: Dart Edge `${dartEdge.errors}` errors, Fastify `${fastify.errors}` errors.';
}
