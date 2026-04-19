import 'dart:convert';

/// Canonical benchmark scenarios exercised by the runner.
enum BenchmarkScenario { plaintext, json, pathParam, echo }

/// Derived metadata for a [BenchmarkScenario].
extension BenchmarkScenarioDetails on BenchmarkScenario {
  /// Stable scenario identifier used in CLI flags and reports.
  String get id => switch (this) {
    BenchmarkScenario.plaintext => 'plaintext',
    BenchmarkScenario.json => 'json',
    BenchmarkScenario.pathParam => 'path_param',
    BenchmarkScenario.echo => 'echo',
  };

  /// HTTP method used to exercise the scenario.
  String get method => switch (this) {
    BenchmarkScenario.echo => 'POST',
    _ => 'GET',
  };

  /// Request path for the scenario.
  String get path => switch (this) {
    BenchmarkScenario.plaintext => '/plaintext',
    BenchmarkScenario.json => '/json',
    BenchmarkScenario.pathParam => '/users/42',
    BenchmarkScenario.echo => '/echo',
  };

  /// Optional request body sent for the scenario.
  String? get requestBody => switch (this) {
    BenchmarkScenario.echo => jsonEncode(_defaultEchoPayload),
    _ => null,
  };

  /// Canonical response value every target must return.
  Object? get expectedResponse => switch (this) {
    BenchmarkScenario.plaintext => 'Hello, World!',
    BenchmarkScenario.json => _helloWorldPayload,
    BenchmarkScenario.pathParam => {'id': '42', 'name': 'Benchmark User'},
    BenchmarkScenario.echo => _defaultEchoPayload,
  };

  /// Whether the scenario response should be compared as JSON.
  bool get expectsJson => switch (this) {
    BenchmarkScenario.plaintext => false,
    _ => true,
  };

  /// Fragment that must appear in the response content type.
  String get expectedContentTypeFragment => switch (this) {
    BenchmarkScenario.plaintext => 'text/plain',
    _ => 'application/json',
  };
}

const _helloWorldPayload = <String, Object?>{'message': 'Hello, World!'};
const _defaultEchoPayload = <String, Object?>{
  'message': 'Echo payload',
  'count': 1,
  'enabled': true,
};

/// Parses a comma-separated scenario list or the special value `all`.
List<BenchmarkScenario> parseBenchmarkScenarios(String value) {
  if (value == 'all') {
    return BenchmarkScenario.values;
  }

  return value
      .split(',')
      .map((scenario) => _parseBenchmarkScenario(scenario.trim()))
      .toList(growable: false);
}

BenchmarkScenario _parseBenchmarkScenario(String value) => switch (value) {
  'plaintext' => BenchmarkScenario.plaintext,
  'json' => BenchmarkScenario.json,
  'path_param' => BenchmarkScenario.pathParam,
  'echo' => BenchmarkScenario.echo,
  _ => throw FormatException(
    'Unknown scenario "$value". Use plaintext, json, path_param, echo, or all.',
  ),
};
