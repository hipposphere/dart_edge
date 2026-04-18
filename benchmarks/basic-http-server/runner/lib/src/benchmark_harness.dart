import 'dart:io';

import 'package:dart_edge_benchmark_shared/dart_edge_benchmark_shared.dart';

import 'benchmark_options.dart';
import 'benchmark_report.dart';
import 'benchmark_target_process.dart';
import 'benchmark_targets.dart';
import 'oha_runner.dart';
import 'resource_sampler.dart';
import 'scenario_validator.dart';

/// Runs the configured benchmark matrix and collects the results.
final class BenchmarkHarness {
  const BenchmarkHarness({required this.options, required this.output});

  final BenchmarkOptions options;
  final IOSink output;

  Future<BenchmarkReport> run() async {
    final benchmarkSuiteRoot = _resolveBenchmarkSuiteRoot();
    final results = <ScenarioBenchmarkResult>[];
    const ohaRunner = OhaRunner();

    await OhaRunner.ensureAvailable();

    for (var index = 0; index < options.targets.length; index++) {
      final targetId = options.targets[index];
      final target = benchmarkTargets[targetId]!;
      final port = options.basePort + index;

      output.writeln('\n== ${target.label} ==');

      final server = await BenchmarkTargetProcess.start(
        target: target,
        benchmarkSuiteRoot: benchmarkSuiteRoot,
        port: port,
      );

      try {
        for (final scenario in options.scenarios) {
          final uri = Uri.http('127.0.0.1:$port', scenario.path);

          output.writeln(
            '  ${scenario.id}: warmup ${options.warmup.inSeconds}s, '
            'measure ${options.duration.inSeconds}s at concurrency ${options.concurrency}',
          );

          await validateScenario(uri: uri, scenario: scenario);

          if (options.warmup > Duration.zero) {
            await ohaRunner.runScenario(
              uri: uri,
              scenario: scenario,
              duration: options.warmup,
              concurrency: options.concurrency,
            );
          }

          final resourceSampler = ResourceSampler(pid: server.process.pid);
          await resourceSampler.start();
          late final OhaScenarioResult measurement;
          late final ResourceUsageSummary resources;
          try {
            measurement = await ohaRunner.runScenario(
              uri: uri,
              scenario: scenario,
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
            requests: measurement.requests,
            errors: measurement.errors,
            requestsPerSecond: measurement.requestsPerSecond,
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
            '    ${result.requestsPerSecond.toStringAsFixed(0)} rps | '
            'p50 ${result.p50LatencyMs.toStringAsFixed(2)} ms | '
            'p99 ${result.p99LatencyMs.toStringAsFixed(2)} ms | '
            'cpu ${result.averageCpuPercent.toStringAsFixed(1)}% avg | '
            'rss ${result.peakMemoryMb.toStringAsFixed(1)} MB peak | '
            'errors ${result.errors}',
          );
        }
      } finally {
        await server.stop();
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

Directory _resolveBenchmarkSuiteRoot() {
  final scriptUri = Platform.script;
  if (scriptUri.scheme == 'file') {
    return File.fromUri(scriptUri).parent.parent.parent.absolute;
  }

  return Directory.current.parent.absolute;
}

void _printResultsTable(List<ScenarioBenchmarkResult> results) {
  stdout.writeln(
    '\nTarget | Scenario | Requests | Errors | RPS | Avg ms | P50 ms | P90 ms | P99 ms | Max ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB',
  );
  stdout.writeln(
    '--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:',
  );

  for (final result in results) {
    stdout.writeln(
      '${result.targetId} | '
      '${result.scenarioId} | '
      '${result.requests} | '
      '${result.errors} | '
      '${result.requestsPerSecond.toStringAsFixed(0)} | '
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
