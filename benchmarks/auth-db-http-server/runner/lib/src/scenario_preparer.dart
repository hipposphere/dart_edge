import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

const _multipartBoundary = 'dart-edge-benchmark-upload-boundary';

/// Prepared request scenario including dynamic auth headers when needed.
final class PreparedRequestScenario {
  const PreparedRequestScenario({
    required this.scenario,
    required this.uri,
    required this.headers,
    this.bodyBytes,
  });

  final BenchmarkScenario scenario;
  final Uri uri;
  final Map<String, String> headers;
  final List<int>? bodyBytes;
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
      headers: {
        'origin': baseUri.origin,
        HttpHeaders.contentTypeHeader: ContentType.json.toString(),
      },
      bodyBytes: utf8.encode(scenario.requestBody!),
    ),
    BenchmarkScenario.rawAuthed ||
    BenchmarkScenario.dbAuthed ||
    BenchmarkScenario.uploadMultipart => () async {
      final session = await createSession(baseUri);
      final headers = <String, String>{
        'authorization': 'Bearer ${session.bearerToken}',
      };
      final bodyBytes = switch (scenario) {
        BenchmarkScenario.uploadMultipart => buildBenchmarkMultipartRequestBody(
          _multipartBoundary,
        ),
        _ => null,
      };
      if (scenario == BenchmarkScenario.uploadMultipart) {
        headers[HttpHeaders.contentTypeHeader] = benchmarkMultipartContentType(
          _multipartBoundary,
        );
      }

      return PreparedRequestScenario(
        scenario: scenario,
        uri: baseUri.resolve(scenario.path),
        headers: headers,
        bodyBytes: bodyBytes,
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
