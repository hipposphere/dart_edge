import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import 'scenario_preparer.dart';

/// Sends one request to a prepared scenario URI and verifies the response.
Future<void> validatePreparedScenario(PreparedRequestScenario prepared) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

  try {
    final request = switch (prepared.scenario.method) {
      'GET' => await client.getUrl(prepared.uri),
      'POST' => await client.postUrl(prepared.uri),
      final method => throw StateError('Unsupported benchmark method $method.'),
    };

    for (final entry in prepared.headers.entries) {
      request.headers.set(entry.key, entry.value);
    }

    if (prepared.body case final body?) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }

    final response = await request.close();
    final contentType = response.headers.contentType?.toString() ?? '';
    final responseBody = await utf8.decoder.bind(response).join();

    switch (prepared.scenario) {
      case BenchmarkScenario.signIn:
        _validateSignInResponse(
          uri: prepared.uri,
          statusCode: response.statusCode,
          contentType: contentType,
          responseBody: responseBody,
        );
        return;
      case BenchmarkScenario.rawAuthed:
        _validateExactJsonResponse(
          scenario: prepared.scenario,
          uri: prepared.uri,
          statusCode: response.statusCode,
          contentType: contentType,
          responseBody: responseBody,
          expectedBody: benchmarkRawResponseJson(benchmarkUserEmail(0)),
        );
        return;
      case BenchmarkScenario.dbAuthed:
        _validateExactJsonResponse(
          scenario: prepared.scenario,
          uri: prepared.uri,
          statusCode: response.statusCode,
          contentType: contentType,
          responseBody: responseBody,
          expectedBody: benchmarkDatabaseResponseJson(benchmarkUserEmail(0)),
        );
        return;
      case BenchmarkScenario.flow:
        throw StateError('Flow validation uses validateFlowScenario().');
    }
  } finally {
    client.close(force: true);
  }
}

/// Validates the full sign-in -> raw -> db flow once before measurement.
Future<void> validateFlowScenario({required Uri baseUri}) async {
  final email = benchmarkUserEmail(0);
  final session = await createSessionWithCredentials(
    baseUri,
    email: email,
    password: benchmarkUserPassword,
  );
  final bearerToken = session.bearerToken;
  await _validateAuthorizedGet(
    uri: baseUri.resolve(benchmarkRawPath),
    bearerToken: bearerToken,
    scenario: BenchmarkScenario.rawAuthed,
    expectedBody: benchmarkRawResponseJson(email),
  );
  await _validateAuthorizedGet(
    uri: baseUri.resolve(benchmarkDatabasePath),
    bearerToken: bearerToken,
    scenario: BenchmarkScenario.dbAuthed,
    expectedBody: benchmarkDatabaseResponseJson(email),
  );
}

Future<void> _validateAuthorizedGet({
  required Uri uri,
  required String bearerToken,
  required BenchmarkScenario scenario,
  required String expectedBody,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

  try {
    final request = await client.getUrl(uri);
    request.headers.set('authorization', 'Bearer $bearerToken');
    final response = await request.close();
    final contentType = response.headers.contentType?.toString() ?? '';
    final responseBody = await utf8.decoder.bind(response).join();

    _validateExactJsonResponse(
      scenario: scenario,
      uri: uri,
      statusCode: response.statusCode,
      contentType: contentType,
      responseBody: responseBody,
      expectedBody: expectedBody,
    );
  } finally {
    client.close(force: true);
  }
}

void _validateSignInResponse({
  required Uri uri,
  required int statusCode,
  required String contentType,
  required String responseBody,
}) {
  if (statusCode != HttpStatus.ok) {
    throw StateError('sign_in returned $statusCode for $uri.');
  }

  if (!contentType.contains('application/json')) {
    throw StateError(
      'sign_in returned unexpected content type "$contentType" for $uri.',
    );
  }

  final decoded = jsonDecode(responseBody);
  if (decoded is! Map<String, Object?>) {
    throw StateError('sign_in returned a non-object response for $uri.');
  }

  final token = decoded['token'];
  final user = decoded['user'];
  if (token is! String || token.isEmpty) {
    throw StateError('sign_in did not return a token for $uri.');
  }
  if (user is! Map || user['email'] != benchmarkUserEmail(0)) {
    throw StateError(
      'sign_in did not return the expected benchmark user for $uri.',
    );
  }
}

void _validateExactJsonResponse({
  required BenchmarkScenario scenario,
  required Uri uri,
  required int statusCode,
  required String contentType,
  required String responseBody,
  required String expectedBody,
}) {
  if (statusCode != HttpStatus.ok) {
    throw StateError('${scenario.id} returned $statusCode for $uri.');
  }

  if (!contentType.contains('application/json')) {
    throw StateError(
      '${scenario.id} returned unexpected content type "$contentType" '
      'for $uri.',
    );
  }

  if (responseBody != expectedBody) {
    throw StateError(
      '${scenario.id} returned unexpected body for $uri.\n'
      'Expected: $expectedBody\n'
      'Actual:   $responseBody',
    );
  }
}
