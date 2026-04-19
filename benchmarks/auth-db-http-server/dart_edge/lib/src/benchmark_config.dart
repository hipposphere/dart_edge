/// Shared Better Auth secret used by benchmark targets.
const benchmarkAuthSecret = 'benchmark-secret-key-that-is-at-least-32-chars';

/// Canonical benchmark user seeded into the Dart Edge target.
const benchmarkUserName = 'Benchmark User';
const benchmarkUserEmail = 'benchmark.user@example.com';
const benchmarkUserPassword = 'password123456';
const benchmarkFlowUserCount = 256;

/// Stable benchmark payload stored in the benchmark database.
const benchmarkDatabaseValue = 'database benchmark value';

/// Parses `--port=` from CLI [args].
int parseBenchmarkPort(List<String> args, {int defaultPort = 8080}) {
  for (final argument in args) {
    if (argument.startsWith('--port=')) {
      return int.parse(argument.substring('--port='.length));
    }
  }

  return defaultPort;
}

/// Builds the canonical origin value used by auth requests.
String benchmarkOriginForPort(int port) => 'http://127.0.0.1:$port';

/// Builds the canonical flow-user name for [index].
String benchmarkFlowUserName(int index) => 'Benchmark Flow User $index';

/// Builds the canonical flow-user email for [index].
String benchmarkFlowUserEmail(int index) => 'benchmark.flow.$index@example.com';
