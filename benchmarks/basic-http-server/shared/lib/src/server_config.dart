/// Plaintext payload returned by the `plaintext` scenario.
const benchmarkPlaintextBody = 'Hello, World!';

/// JSON payload returned by the `json` scenario.
const benchmarkJsonBody = '{"message":"Hello, World!"}';

/// JSON payload sent to and returned from the `echo` scenario.
const benchmarkEchoBody = '{"message":"Echo payload","count":1,"enabled":true}';

/// Parses `--port=` from CLI [args].
int parseBenchmarkPort(List<String> args, {int defaultPort = 8080}) {
  for (final argument in args) {
    if (argument.startsWith('--port=')) {
      return int.parse(argument.substring('--port='.length));
    }
  }

  return defaultPort;
}

/// Builds the canonical JSON response for the `path_param` scenario.
String benchmarkUserJson(String id) {
  return '{"id":"$id","name":"Benchmark User"}';
}
