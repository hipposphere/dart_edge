import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'process_utils.dart';
import 'test_suite_runner.dart';

final class ServerBenchmarkConfig {
  const ServerBenchmarkConfig({
    required this.projectRoot,
    required this.url,
    required this.duration,
    required this.concurrency,
    required this.warmup,
    required this.outputPath,
    required this.headers,
    required this.method,
    required this.githubSummary,
    this.composeFile,
    this.composeProjectName,
    this.composeDown = true,
    this.healthUrl,
    this.healthTimeout = const Duration(seconds: 90),
    this.container,
    this.maxP95LatencyMs,
    this.minThroughput,
  });

  final Directory projectRoot;
  final Uri url;
  final Duration duration;
  final int concurrency;
  final Duration warmup;
  final String outputPath;
  final Map<String, String> headers;
  final String method;
  final bool githubSummary;
  final String? composeFile;
  final String? composeProjectName;
  final bool composeDown;
  final Uri? healthUrl;
  final Duration healthTimeout;
  final String? container;
  final double? maxP95LatencyMs;
  final double? minThroughput;
}

final class ServerBenchmarkRunner {
  const ServerBenchmarkRunner({
    this.processRunner = const CommandProcessRunner(),
    this.testSuiteRunner = const TestSuiteRunner(),
  });

  final CommandProcessRunner processRunner;
  final TestSuiteRunner testSuiteRunner;

  Future<int> run(ServerBenchmarkConfig config) async {
    var composeStarted = false;
    try {
      if (config.composeFile != null) {
        await _compose(config, ['up', '--build', '--detach']);
        composeStarted = true;
      }
      if (config.healthUrl != null) {
        await testSuiteRunner.waitForHttpOk(
          config.healthUrl!,
          timeout: config.healthTimeout,
        );
      }

      if (config.warmup > Duration.zero) {
        stdout.writeln(
          'Warming up ${config.url} for ${config.warmup.inSeconds}s',
        );
        await _measure(
          config,
          duration: config.warmup,
          collectResources: false,
        );
      }

      stdout.writeln(
        'Benchmarking ${config.url} for ${config.duration.inSeconds}s '
        'with concurrency ${config.concurrency}',
      );
      final result = await _measure(config, duration: config.duration);
      await _writeResult(config, result);

      if (config.githubSummary) {
        await writeGithubSummary(result.toMarkdown());
      }

      stdout.writeln(result.toConsoleSummary());
      final failed = result.failedThresholds(
        maxP95LatencyMs: config.maxP95LatencyMs,
        minThroughput: config.minThroughput,
      );
      for (final failure in failed) {
        stderr.writeln('Benchmark threshold failed: $failure');
      }
      return failed.isEmpty ? 0 : 1;
    } finally {
      if (composeStarted && config.composeDown) {
        await _compose(config, ['down', '--remove-orphans']);
      }
    }
  }

  Future<BenchmarkResult> _measure(
    ServerBenchmarkConfig config, {
    required Duration duration,
    bool collectResources = true,
  }) async {
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    final latencies = <int>[];
    final statusCodes = <int, int>{};
    final errors = <String, int>{};
    final resourceSamples = <ResourceSample>[];
    Timer? resourceTimer;

    if (collectResources && config.container != null) {
      resourceTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final sample = await _sampleContainer(config.container!);
        if (sample != null) {
          resourceSamples.add(sample);
        }
      });
    }

    Future<void> worker() async {
      while (stopwatch.elapsed < duration) {
        final requestStopwatch = Stopwatch()..start();
        try {
          final request = await client.openUrl(config.method, config.url);
          for (final entry in config.headers.entries) {
            request.headers.set(entry.key, entry.value);
          }
          final response = await request.close();
          await response.drain<void>();
          requestStopwatch.stop();
          latencies.add(requestStopwatch.elapsedMicroseconds);
          statusCodes.update(
            response.statusCode,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        } on Object catch (error) {
          requestStopwatch.stop();
          errors.update(
            error.runtimeType.toString(),
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    await Future.wait([
      for (var index = 0; index < config.concurrency; index++) worker(),
    ]);
    resourceTimer?.cancel();
    client.close(force: true);
    stopwatch.stop();

    return BenchmarkResult(
      url: config.url.toString(),
      method: config.method,
      durationMs: stopwatch.elapsedMilliseconds,
      concurrency: config.concurrency,
      latenciesMicros: latencies,
      statusCodes: statusCodes,
      errors: errors,
      resourceSamples: resourceSamples,
    );
  }

  Future<ResourceSample?> _sampleContainer(String container) async {
    final result = await processRunner.runBuffered('docker', [
      'stats',
      '--no-stream',
      '--format',
      '{{json .}}',
      container,
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = result.stdout.toString().trim();
    if (output.isEmpty) {
      return null;
    }
    final json = jsonDecode(output) as Map<String, Object?>;
    return ResourceSample(
      timestamp: DateTime.now().toUtc(),
      cpuPercent: _parsePercent(json['CPUPerc'] as String?),
      memoryUsage: json['MemUsage'] as String?,
      memoryPercent: _parsePercent(json['MemPerc'] as String?),
    );
  }

  Future<void> _writeResult(
    ServerBenchmarkConfig config,
    BenchmarkResult result,
  ) async {
    final output = File(
      p.isAbsolute(config.outputPath)
          ? config.outputPath
          : p.join(config.projectRoot.path, config.outputPath),
    );
    await output.parent.create(recursive: true);
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result.toJson()),
    );
    stdout.writeln('Wrote benchmark report: ${output.path}');
  }

  Future<void> _compose(
    ServerBenchmarkConfig config,
    List<String> arguments,
  ) async {
    final command = [
      'docker',
      'compose',
      if (config.composeFile case final composeFile?) ...[
        '--file',
        composeFile,
      ],
      if (config.composeProjectName case final projectName?) ...[
        '--project-name',
        projectName,
      ],
      ...arguments,
    ];
    stdout.writeln('Running: ${shellCommand(command)}');
    final exitCode = await processRunner.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: config.projectRoot.path,
    );
    if (exitCode != 0) {
      throw TestSuiteException(
        'Docker compose command failed with exit code $exitCode.',
      );
    }
  }
}

final class BenchmarkResult {
  const BenchmarkResult({
    required this.url,
    required this.method,
    required this.durationMs,
    required this.concurrency,
    required this.latenciesMicros,
    required this.statusCodes,
    required this.errors,
    required this.resourceSamples,
  });

  final String url;
  final String method;
  final int durationMs;
  final int concurrency;
  final List<int> latenciesMicros;
  final Map<int, int> statusCodes;
  final Map<String, int> errors;
  final List<ResourceSample> resourceSamples;

  int get requestCount => latenciesMicros.length;

  int get errorCount => errors.values.fold(0, (total, value) => total + value);

  double get throughput =>
      durationMs == 0 ? 0 : requestCount / (durationMs / 1000);

  double percentile(double percentile) {
    if (latenciesMicros.isEmpty) {
      return 0;
    }
    final sorted = [...latenciesMicros]..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index] / 1000;
  }

  List<String> failedThresholds({
    double? maxP95LatencyMs,
    double? minThroughput,
  }) {
    return [
      if (maxP95LatencyMs != null && percentile(0.95) > maxP95LatencyMs)
        'p95 ${percentile(0.95).toStringAsFixed(1)}ms > ${maxP95LatencyMs.toStringAsFixed(1)}ms',
      if (minThroughput != null && throughput < minThroughput)
        'throughput ${throughput.toStringAsFixed(1)}rps < ${minThroughput.toStringAsFixed(1)}rps',
    ];
  }

  Map<String, Object?> toJson() {
    return {
      'url': url,
      'method': method,
      'duration_ms': durationMs,
      'concurrency': concurrency,
      'requests': requestCount,
      'errors': errorCount,
      'throughput_rps': throughput,
      'latency_ms': {
        'p50': percentile(0.50),
        'p95': percentile(0.95),
        'p99': percentile(0.99),
      },
      'status_codes': {
        for (final entry in statusCodes.entries)
          entry.key.toString(): entry.value,
      },
      'error_types': errors,
      'resources': [for (final sample in resourceSamples) sample.toJson()],
    };
  }

  String toConsoleSummary() {
    return 'requests=$requestCount errors=$errorCount '
        'throughput=${throughput.toStringAsFixed(1)}rps '
        'p50=${percentile(0.50).toStringAsFixed(1)}ms '
        'p95=${percentile(0.95).toStringAsFixed(1)}ms '
        'p99=${percentile(0.99).toStringAsFixed(1)}ms';
  }

  String toMarkdown() {
    return '''
## Server Benchmark

| Metric | Value |
| --- | ---: |
| URL | `$url` |
| Method | `$method` |
| Duration | `${durationMs}ms` |
| Concurrency | `$concurrency` |
| Requests | `$requestCount` |
| Errors | `$errorCount` |
| Throughput | `${throughput.toStringAsFixed(1)} rps` |
| p50 latency | `${percentile(0.50).toStringAsFixed(1)} ms` |
| p95 latency | `${percentile(0.95).toStringAsFixed(1)} ms` |
| p99 latency | `${percentile(0.99).toStringAsFixed(1)} ms` |

''';
  }
}

final class ResourceSample {
  const ResourceSample({
    required this.timestamp,
    required this.cpuPercent,
    required this.memoryUsage,
    required this.memoryPercent,
  });

  final DateTime timestamp;
  final double? cpuPercent;
  final String? memoryUsage;
  final double? memoryPercent;

  Map<String, Object?> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'cpu_percent': cpuPercent,
      'memory_usage': memoryUsage,
      'memory_percent': memoryPercent,
    };
  }
}

double? _parsePercent(String? value) {
  if (value == null) {
    return null;
  }
  return double.tryParse(value.replaceAll('%', '').trim());
}
