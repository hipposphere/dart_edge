import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import 'benchmark_options.dart';
import 'benchmark_report.dart';
import 'benchmark_target_process.dart';
import 'benchmark_targets.dart';
import 'load_result.dart';
import 'resource_sampler.dart';
import 'virtual_user_runner.dart';

/// Runs the configured benchmark matrix and collects the results.
final class BenchmarkHarness {
  const BenchmarkHarness({required this.options, required this.output});

  final BenchmarkOptions options;
  final IOSink output;

  Future<BenchmarkReport> run() async {
    final repoRoot = _resolveRepoRoot();
    final results = <ScenarioBenchmarkResult>[];
    const virtualUserRunner = VirtualUserRunner();

    output.writeln(
      'CPU cap: ${options.singleCore ? 'single-core (~100% total CPU)' : 'disabled'}',
    );

    for (
      var targetIndex = 0;
      targetIndex < options.targets.length;
      targetIndex++
    ) {
      final targetId = options.targets[targetIndex];
      final target = benchmarkTargets[targetId]!;
      final port = options.basePort + targetIndex;

      output.writeln('\n== ${target.label} ==');

      for (final scenario in options.scenarios) {
        output.writeln(
          '  ${scenario.id}: warmup ${options.warmup.inSeconds}s, '
          'measure ${options.duration.inSeconds}s at concurrency ${options.concurrency}',
        );

        final server = await BenchmarkTargetProcess.start(
          target: target,
          repoRoot: repoRoot,
          port: port,
          singleCore: options.singleCore,
        );

        try {
          final baseUri = Uri.http('127.0.0.1:$port');
          late final ScenarioLoadResult measurement;
          late final ResourceUsageSummary resources;

          await virtualUserRunner.validateScenario(
            scenario: scenario,
            baseUri: baseUri,
          );

          if (options.warmup > Duration.zero) {
            await virtualUserRunner.runScenario(
              scenario: scenario,
              baseUri: baseUri,
              duration: options.warmup,
              concurrency: options.concurrency,
            );
          }

          final resourceSampler = ResourceSampler(pid: server.process.pid);
          await resourceSampler.start();
          try {
            measurement = await virtualUserRunner.runScenario(
              scenario: scenario,
              baseUri: baseUri,
              duration: options.duration,
              concurrency: options.concurrency,
            );
          } finally {
            resources = await resourceSampler.stop();
          }

          final result = ScenarioBenchmarkResult(
            targetId: target.id,
            targetLabel: target.label,
            scenarioId: scenario.id,
            operations: measurement.operations,
            errors: measurement.errors,
            operationsPerSecond: measurement.operationsPerSecond,
            averageLatencyMs: measurement.averageLatencyMs,
            p50LatencyMs: measurement.p50LatencyMs,
            p90LatencyMs: measurement.p90LatencyMs,
            p99LatencyMs: measurement.p99LatencyMs,
            maxLatencyMs: measurement.maxLatencyMs,
            averageCpuPercent: resources.averageCpuPercent,
            peakCpuPercent: resources.peakCpuPercent,
            averageMemoryMb: resources.averageMemoryMb,
            peakMemoryMb: resources.peakMemoryMb,
            firstError: measurement.firstError,
          );

          results.add(result);
          output.writeln(
            '    ${result.operationsPerSecond.toStringAsFixed(1)} ops/s | '
            'p50 ${result.p50LatencyMs.toStringAsFixed(2)} ms | '
            'p99 ${result.p99LatencyMs.toStringAsFixed(2)} ms | '
            'cpu ${result.averageCpuPercent.toStringAsFixed(1)}% avg | '
            'rss ${result.peakMemoryMb.toStringAsFixed(1)} MB peak | '
            'errors ${result.errors}',
          );
        } finally {
          await server.stop();
        }
      }
    }

    _printResultsTable(results);

    return BenchmarkReport(
      generatedAt: DateTime.now().toUtc(),
      options: options,
      results: results,
    );
  }
}

Directory _resolveRepoRoot() {
  final candidates = <Directory>[
    if (Platform.script.scheme == 'file') File.fromUri(Platform.script).parent,
    Directory.current.absolute,
  ];

  for (final candidate in candidates) {
    final repoRoot = _findRepoRoot(candidate);
    if (repoRoot != null) {
      return repoRoot;
    }
  }

  throw StateError(
    'Could not resolve the repository root for auth-db benchmarks.',
  );
}

Directory? _findRepoRoot(Directory start) {
  var current = start.absolute;

  while (true) {
    final marker = File(
      '${current.path}/benchmarks/auth-db-http-server/runner/pubspec.yaml',
    );
    if (marker.existsSync()) {
      return current;
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      return null;
    }
    current = parent;
  }
}

void _printResultsTable(List<ScenarioBenchmarkResult> results) {
  stdout.writeln(
    '\nTarget | Scenario | Ops | Errors | Ops/s | Avg ms | P50 ms | P90 ms | P99 ms | Max ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB',
  );
  stdout.writeln(
    '--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:',
  );

  for (final result in results) {
    stdout.writeln(
      '${result.targetId} | '
      '${result.scenarioId} | '
      '${result.operations} | '
      '${result.errors} | '
      '${result.operationsPerSecond.toStringAsFixed(1)} | '
      '${result.averageLatencyMs.toStringAsFixed(2)} | '
      '${result.p50LatencyMs.toStringAsFixed(2)} | '
      '${result.p90LatencyMs.toStringAsFixed(2)} | '
      '${result.p99LatencyMs.toStringAsFixed(2)} | '
      '${result.maxLatencyMs.toStringAsFixed(2)} | '
      '${result.averageCpuPercent.toStringAsFixed(1)} | '
      '${result.peakCpuPercent.toStringAsFixed(1)} | '
      '${result.averageMemoryMb.toStringAsFixed(1)} | '
      '${result.peakMemoryMb.toStringAsFixed(1)}',
    );
  }
}
