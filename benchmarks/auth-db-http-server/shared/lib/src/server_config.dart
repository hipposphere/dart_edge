import 'dart:convert';

/// Plain-text response returned by the health probe route.
const benchmarkHealthBody = 'ok';

/// Shared Better Auth secret used by both benchmark targets.
const benchmarkAuthSecret = 'benchmark-secret-key-that-is-at-least-32-chars';

/// Number of benchmark users seeded into both targets.
const benchmarkUserCount = 256;

const benchmarkUserPassword = 'password123456';

/// Stable benchmark route layout.
const benchmarkAuthPath = '/auth';
const benchmarkHealthPath = '/healthz';
const benchmarkRawPath = '/bench/raw';
const benchmarkDatabasePath = '/bench/db';

/// Stable benchmark payloads.
const benchmarkRawValue = 'raw benchmark value';
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

/// Builds the canonical sign-in request body for benchmark user [index].
String benchmarkSignInRequestJson([int index = 0]) {
  return jsonEncode({
    'email': benchmarkUserEmail(index),
    'password': benchmarkUserPassword,
  });
}

/// Builds the canonical authed raw response body.
String benchmarkRawResponseJson(String email) {
  return jsonEncode({'email': email, 'value': benchmarkRawValue});
}

/// Builds the canonical authed database response body.
String benchmarkDatabaseResponseJson(String email) {
  return jsonEncode({'email': email, 'value': benchmarkDatabaseValue});
}
