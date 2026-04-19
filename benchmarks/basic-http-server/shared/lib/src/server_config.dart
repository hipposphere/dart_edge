import 'dart:convert';

/// Plaintext payload returned by the `plaintext` scenario.
const benchmarkPlaintextBody = 'Hello, World!';

/// JSON payload returned by the `json` scenario.
const benchmarkJsonPayload = <String, Object?>{'message': 'Hello, World!'};

/// JSON payload sent to and returned from the `echo` scenario.
const benchmarkEchoPayload = <String, Object?>{
  'message': 'Echo payload',
  'count': 1,
  'enabled': true,
};

/// Encodes a benchmark JSON [payload] using Dart's standard JSON encoder.
String encodeBenchmarkJson(Object? payload) => jsonEncode(payload);

/// Parses `--port=` from CLI [args].
int parseBenchmarkPort(List<String> args, {int defaultPort = 8080}) {
  for (final argument in args) {
    if (argument.startsWith('--port=')) {
      return int.parse(argument.substring('--port='.length));
    }
  }

  return defaultPort;
}

/// Builds the canonical JSON response payload for the `path_param` scenario.
Map<String, Object?> benchmarkUserPayload(String id) {
  return {'id': id, 'name': 'Benchmark User'};
}
