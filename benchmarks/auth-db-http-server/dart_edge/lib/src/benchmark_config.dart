/// Shared Better Auth secret used by benchmark targets.
const benchmarkAuthSecret = 'benchmark-secret-key-that-is-at-least-32-chars';

/// Number of benchmark users seeded into the Dart Edge target.
const benchmarkUserCount = 256;

const benchmarkUserPassword = 'password123456';

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

/// Builds the canonical benchmark user name for [index].
String benchmarkUserName(int index) => 'Benchmark User $index';

/// Builds the canonical benchmark user email for [index].
String benchmarkUserEmail(int index) => 'benchmark.user-$index@example.com';
