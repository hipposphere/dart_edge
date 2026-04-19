import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

/// Prepared request scenario including dynamic auth headers when needed.
final class PreparedRequestScenario {
  const PreparedRequestScenario({
    required this.scenario,
    required this.uri,
    required this.headers,
    this.body,
  });

  final BenchmarkScenario scenario;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

/// Auth context created through the benchmark's sign-in route.
final class BenchmarkAuthSession {
  const BenchmarkAuthSession({required this.bearerToken});

  final String bearerToken;
}

Future<PreparedRequestScenario> prepareRequestScenario({
  required Uri baseUri,
  required BenchmarkScenario scenario,
}) async {
  return switch (scenario) {
    BenchmarkScenario.signIn => PreparedRequestScenario(
      scenario: scenario,
      uri: baseUri.resolve(scenario.path),
      headers: {'origin': baseUri.origin},
      body: scenario.requestBody,
    ),
    BenchmarkScenario.rawAuthed || BenchmarkScenario.dbAuthed => () async {
      final session = await createSession(baseUri);
      return PreparedRequestScenario(
        scenario: scenario,
        uri: baseUri.resolve(scenario.path),
        headers: {'authorization': 'Bearer ${session.bearerToken}'},
      );
    }(),
    BenchmarkScenario.flow => throw StateError(
      'Flow scenarios do not use prepared request metadata.',
    ),
  };
}

Future<BenchmarkAuthSession> createSession(Uri baseUri) async {
  return createSessionWithCredentials(
    baseUri,
    email: benchmarkUserEmail(0),
    password: benchmarkUserPassword,
  );
}

Future<BenchmarkAuthSession> createSessionWithCredentials(
  Uri baseUri, {
  required String email,
  required String password,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

  try {
    final request = await client.postUrl(
      baseUri.resolve('/auth/sign-in/email'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set('origin', baseUri.origin);
    request.write('{"email":"$email","password":"$password"}');

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();

    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'Sign-in setup returned ${response.statusCode}.\n$responseBody',
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, Object?>) {
      throw StateError('Sign-in setup returned a non-object response.');
    }

    final user = decoded['user'];
    if (user is! Map || user['email'] != email) {
      throw StateError(
        'Sign-in setup response did not include the expected user email.',
      );
    }

    final token = decoded['token'];
    if (token is! String || token.isEmpty) {
      throw StateError('Sign-in setup response did not include a token.');
    }

    return BenchmarkAuthSession(bearerToken: token);
  } finally {
    client.close(force: true);
  }
}
