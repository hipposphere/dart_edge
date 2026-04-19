import 'benchmark_scenarios.dart';
import 'benchmark_targets.dart';

/// Parsed CLI options for the benchmark runner.
final class BenchmarkOptions {
  const BenchmarkOptions({
    required this.targets,
    required this.scenarios,
    required this.warmup,
    required this.duration,
    required this.concurrency,
    required this.basePort,
    this.jsonOut,
    this.showHelp = false,
  });

  final List<String> targets;
  final List<BenchmarkScenario> scenarios;
  final Duration warmup;
  final Duration duration;
  final int concurrency;
  final int basePort;
  final String? jsonOut;
  final bool showHelp;

  static String get usage => '''
Usage: dart run benchmarks/basic-http-server/runner/bin/run.dart [options]

Options:
  --targets=dart_edge,shelf_router,express,fastapi
                                        Comma-separated target ids, or all default non-JIT targets.
  --scenarios=plaintext,json,echo       Comma-separated scenarios, or all.
  --warmup=2                            Warmup seconds per scenario.
  --duration=5                          Measurement seconds per scenario.
  --concurrency=64                      Concurrent client workers.
  --base-port=9080                      First server port; later targets increment.
  --json-out=latest.json                Optional JSON output file.
  --help                                Show this message.
''';

  factory BenchmarkOptions.parse(List<String> args) {
    var targets = defaultBenchmarkTargetIds;
    var scenarios = BenchmarkScenario.values;
    var warmup = const Duration(seconds: 2);
    var duration = const Duration(seconds: 5);
    var concurrency = 64;
    var basePort = 9080;
    String? jsonOut;
    var showHelp = false;

    for (final argument in args) {
      if (argument == '--help') {
        showHelp = true;
        continue;
      }

      if (argument.startsWith('--targets=')) {
        targets = _parseTargets(argument.substring('--targets='.length));
        continue;
      }

      if (argument.startsWith('--scenarios=')) {
        scenarios = parseBenchmarkScenarios(
          argument.substring('--scenarios='.length),
        );
        continue;
      }

      if (argument.startsWith('--warmup=')) {
        warmup = Duration(
          seconds: int.parse(argument.substring('--warmup='.length)),
        );
        continue;
      }

      if (argument.startsWith('--duration=')) {
        duration = Duration(
          seconds: int.parse(argument.substring('--duration='.length)),
        );
        continue;
      }

      if (argument.startsWith('--concurrency=')) {
        concurrency = int.parse(argument.substring('--concurrency='.length));
        continue;
      }

      if (argument.startsWith('--base-port=')) {
        basePort = int.parse(argument.substring('--base-port='.length));
        continue;
      }

      if (argument.startsWith('--json-out=')) {
        jsonOut = argument.substring('--json-out='.length);
        continue;
      }

      throw FormatException('Unknown argument "$argument".');
    }

    if (concurrency <= 0) {
      throw FormatException('--concurrency must be greater than zero.');
    }
    if (duration <= Duration.zero) {
      throw FormatException('--duration must be greater than zero.');
    }
    if (warmup < Duration.zero) {
      throw FormatException('--warmup cannot be negative.');
    }

    return BenchmarkOptions(
      targets: targets,
      scenarios: scenarios,
      warmup: warmup,
      duration: duration,
      concurrency: concurrency,
      basePort: basePort,
      jsonOut: jsonOut,
      showHelp: showHelp,
    );
  }
}

/// Parses the `--targets=` option value.
List<String> _parseTargets(String value) {
  if (value == 'all') {
    return defaultBenchmarkTargetIds;
  }

  return value
      .split(',')
      .map((target) {
        final normalized = target.trim();
        if (!benchmarkTargets.containsKey(normalized)) {
          throw FormatException(
            'Unknown target "$normalized". Use ${benchmarkTargets.keys.join(', ')} or all.',
          );
        }
        return normalized;
      })
      .toList(growable: false);
}

/// Benchmark targets included by default when `--targets` is omitted.
final defaultBenchmarkTargetIds = benchmarkTargets.entries
    .where((entry) => !entry.key.endsWith('_jit'))
    .map((entry) => entry.key)
    .toList(growable: false);
