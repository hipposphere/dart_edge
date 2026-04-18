import 'dart:convert';

import 'package:dart_edge_benchmark_shared/dart_edge_benchmark_shared.dart';

import 'benchmark_options.dart';

/// Benchmark result for one target/scenario pair.
final class ScenarioBenchmarkResult {
  const ScenarioBenchmarkResult({
    required this.targetId,
    required this.targetLabel,
    required this.scenarioId,
    required this.requests,
    required this.errors,
    required this.requestsPerSecond,
    required this.averageLatencyMs,
    required this.p50LatencyMs,
    required this.p90LatencyMs,
    required this.p99LatencyMs,
    required this.maxLatencyMs,
    required this.averageCpuPercent,
    required this.peakCpuPercent,
    required this.averageMemoryMb,
    required this.peakMemoryMb,
    this.firstError,
  });

  final String targetId;
  final String targetLabel;
  final String scenarioId;
  final int requests;
  final int errors;
  final double requestsPerSecond;
  final double averageLatencyMs;
  final double p50LatencyMs;
  final double p90LatencyMs;
  final double p99LatencyMs;
  final double maxLatencyMs;
  final double averageCpuPercent;
  final double peakCpuPercent;
  final double averageMemoryMb;
  final double peakMemoryMb;
  final String? firstError;

  Map<String, Object?> toJson() => {
    'targetId': targetId,
    'targetLabel': targetLabel,
    'scenarioId': scenarioId,
    'requests': requests,
    'errors': errors,
    'requestsPerSecond': requestsPerSecond,
    'averageLatencyMs': averageLatencyMs,
    'p50LatencyMs': p50LatencyMs,
    'p90LatencyMs': p90LatencyMs,
    'p99LatencyMs': p99LatencyMs,
    'maxLatencyMs': maxLatencyMs,
    'averageCpuPercent': averageCpuPercent,
    'peakCpuPercent': peakCpuPercent,
    'averageMemoryMb': averageMemoryMb,
    'peakMemoryMb': peakMemoryMb,
    'firstError': firstError,
  };
}

/// Full benchmark run report.
final class BenchmarkReport {
  const BenchmarkReport({
    required this.generatedAt,
    required this.options,
    required this.results,
  });

  final DateTime generatedAt;
  final BenchmarkOptions options;
  final List<ScenarioBenchmarkResult> results;

  Map<String, Object?> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'options': {
      'targets': options.targets,
      'scenarios': options.scenarios.map((scenario) => scenario.id).toList(),
      'warmupSeconds': options.warmup.inSeconds,
      'durationSeconds': options.duration.inSeconds,
      'concurrency': options.concurrency,
      'basePort': options.basePort,
      'jsonOut': options.jsonOut,
    },
    'results': results.map((result) => result.toJson()).toList(),
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
