import 'server_config.dart';

/// Scenario execution style used by the benchmark runner.
enum BenchmarkScenarioKind { request, flow }

/// Canonical benchmark scenarios served by every target.
enum BenchmarkScenario { signIn, rawAuthed, dbAuthed, flow }

/// Derived metadata for a [BenchmarkScenario].
extension BenchmarkScenarioDetails on BenchmarkScenario {
  /// Stable scenario identifier used in CLI flags and reports.
  String get id => switch (this) {
    BenchmarkScenario.signIn => 'sign_in',
    BenchmarkScenario.rawAuthed => 'raw_authed',
    BenchmarkScenario.dbAuthed => 'db_authed',
    BenchmarkScenario.flow => 'flow',
  };

  /// Human-readable label used in markdown summaries.
  String get label => switch (this) {
    BenchmarkScenario.signIn => 'Sign In',
    BenchmarkScenario.rawAuthed => 'Authenticated Raw',
    BenchmarkScenario.dbAuthed => 'Authenticated DB',
    BenchmarkScenario.flow => 'End-to-End Flow',
  };

  /// Benchmark driver kind for this scenario.
  BenchmarkScenarioKind get kind => switch (this) {
    BenchmarkScenario.flow => BenchmarkScenarioKind.flow,
    _ => BenchmarkScenarioKind.request,
  };

  /// HTTP method used by request-style scenarios.
  String get method => switch (this) {
    BenchmarkScenario.signIn => 'POST',
    BenchmarkScenario.rawAuthed => 'GET',
    BenchmarkScenario.dbAuthed => 'GET',
    BenchmarkScenario.flow => 'FLOW',
  };

  /// Request path used by request-style scenarios.
  String get path => switch (this) {
    BenchmarkScenario.signIn => '$benchmarkAuthPath/sign-in/email',
    BenchmarkScenario.rawAuthed => benchmarkRawPath,
    BenchmarkScenario.dbAuthed => benchmarkDatabasePath,
    BenchmarkScenario.flow => '/flow',
  };

  /// Optional request body sent for request-style scenarios.
  String? get requestBody => switch (this) {
    BenchmarkScenario.signIn => benchmarkSignInRequestJson(),
    _ => null,
  };
}

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
  'sign_in' => BenchmarkScenario.signIn,
  'raw_authed' => BenchmarkScenario.rawAuthed,
  'db_authed' => BenchmarkScenario.dbAuthed,
  'flow' => BenchmarkScenario.flow,
  _ => throw FormatException(
    'Unknown scenario "$value". Use sign_in, raw_authed, db_authed, flow, or all.',
  ),
};
