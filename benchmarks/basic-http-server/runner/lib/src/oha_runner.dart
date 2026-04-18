import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_benchmark_shared/dart_edge_benchmark_shared.dart';

/// Parsed result of one `oha` benchmark scenario run.
final class OhaScenarioResult {
  const OhaScenarioResult({
    required this.requests,
    required this.errors,
    required this.requestsPerSecond,
    required this.averageLatencyMs,
    required this.p50LatencyMs,
    required this.p90LatencyMs,
    required this.p99LatencyMs,
    required this.maxLatencyMs,
    this.firstError,
  });

  final int requests;
  final int errors;
  final double requestsPerSecond;
  final double averageLatencyMs;
  final double p50LatencyMs;
  final double p90LatencyMs;
  final double p99LatencyMs;
  final double maxLatencyMs;
  final String? firstError;
}

/// Thin wrapper around the external `oha` HTTP benchmark tool.
final class OhaRunner {
  const OhaRunner();

  static Future<void> ensureAvailable() async {
    try {
      final result = await Process.run(
        'oha',
        const ['--version'],
        environment: const {'NO_COLOR': 'true'},
      );
      if (result.exitCode == 0) {
        return;
      }
    } on ProcessException {
      // Fall through to the standard error below.
    }

    throw StateError(
      '`oha` is required for benchmarks. Install it with '
      '`cargo install oha --locked`.',
    );
  }

  Future<OhaScenarioResult> runScenario({
    required Uri uri,
    required BenchmarkScenario scenario,
    required Duration duration,
    int concurrency = 1,
  }) async {
    final args = <String>[
      '--no-tui',
      '--output-format',
      'json',
      '-w',
      '-z',
      '${duration.inMilliseconds}ms',
      '-c',
      '$concurrency',
      '-m',
      scenario.method,
    ];

    if (scenario.requestBody case final body?) {
      args
        ..addAll(['-T', 'application/json'])
        ..addAll(['-d', body]);
    }

    args.add(uri.toString());

    final result = await Process.run(
      'oha',
      args,
      environment: const {'NO_COLOR': 'true'},
    );

    if (result.exitCode != 0) {
      throw StateError(
        'oha failed for ${scenario.id}.\n'
        'stdout:\n${result.stdout}\n'
        'stderr:\n${result.stderr}',
      );
    }

    final json = jsonDecode(result.stdout as String) as Map<String, Object?>;
    return _parseOhaJson(json);
  }
}

OhaScenarioResult _parseOhaJson(Map<String, Object?> json) {
  final summary = json['summary'] as Map<String, Object?>? ?? const {};
  final latencyPercentiles =
      json['latencyPercentiles'] as Map<String, Object?>? ?? const {};
  final statusCodeDistribution =
      json['statusCodeDistribution'] as Map<String, Object?>? ?? const {};
  final errorDistribution =
      json['errorDistribution'] as Map<String, Object?>? ?? const {};

  final errorCount = _sumDistribution(errorDistribution);
  final requestCount = _sumDistribution(statusCodeDistribution) + errorCount;

  return OhaScenarioResult(
    requests: requestCount,
    errors: errorCount,
    requestsPerSecond: _readDouble(summary, 'requestsPerSec') ?? 0,
    averageLatencyMs: (_readDouble(summary, 'average') ?? 0) * 1000,
    p50LatencyMs: (_readDouble(latencyPercentiles, 'p50') ?? 0) * 1000,
    p90LatencyMs: (_readDouble(latencyPercentiles, 'p90') ?? 0) * 1000,
    p99LatencyMs: (_readDouble(latencyPercentiles, 'p99') ?? 0) * 1000,
    maxLatencyMs: (_readDouble(summary, 'slowest') ?? 0) * 1000,
    firstError: errorDistribution.isEmpty ? null : errorDistribution.keys.first,
  );
}

int _sumDistribution(Map<String, Object?> distribution) {
  var total = 0;
  for (final value in distribution.values) {
    total += (value as num).toInt();
  }
  return total;
}

double? _readDouble(Map<String, Object?> values, String key) {
  final value = values[key];
  return switch (value) {
    null => null,
    num() => value.toDouble(),
    _ => null,
  };
}
