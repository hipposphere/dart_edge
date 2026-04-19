import 'dart:convert';
import 'dart:io';

import 'benchmark_scenarios.dart';

/// Sends one request to [uri] and verifies that the response matches
/// [scenario].
Future<void> validateScenario({
  required Uri uri,
  required BenchmarkScenario scenario,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

  try {
    final request = switch (scenario.method) {
      'GET' => await client.getUrl(uri),
      'POST' => await client.postUrl(uri),
      final method => throw StateError('Unsupported benchmark method $method.'),
    };

    if (scenario.requestBody case final body?) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }

    final response = await request.close();
    final contentType = response.headers.contentType?.toString() ?? '';
    final responseBody = await utf8.decoder.bind(response).join();

    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        '${scenario.id} returned ${response.statusCode} for $uri.',
      );
    }

    if (!contentType.contains(scenario.expectedContentTypeFragment)) {
      throw StateError(
        '${scenario.id} returned unexpected content type "$contentType" '
        'for $uri.',
      );
    }

    if (scenario.expectsJson) {
      final actualJson = _decodeJsonBody(
        body: responseBody,
        scenario: scenario,
        uri: uri,
      );
      if (!_jsonDeepEquals(actualJson, scenario.expectedResponse)) {
        throw StateError(
          '${scenario.id} returned unexpected JSON body for $uri.\n'
          'Expected: ${jsonEncode(scenario.expectedResponse)}\n'
          'Actual:   $responseBody',
        );
      }
      return;
    }

    if (responseBody != scenario.expectedResponse) {
      throw StateError(
        '${scenario.id} returned unexpected body for $uri.\n'
        'Expected: ${scenario.expectedResponse}\n'
        'Actual:   $responseBody',
      );
    }
  } finally {
    client.close(force: true);
  }
}

Object? _decodeJsonBody({
  required String body,
  required BenchmarkScenario scenario,
  required Uri uri,
}) {
  try {
    return jsonDecode(body);
  } on FormatException catch (error) {
    throw StateError(
      '${scenario.id} returned invalid JSON for $uri.\n'
      'Error: $error\n'
      'Body: $body',
    );
  }
}

bool _jsonDeepEquals(Object? actual, Object? expected) {
  if (actual is List<Object?> && expected is List<Object?>) {
    if (actual.length != expected.length) {
      return false;
    }

    for (var i = 0; i < actual.length; i++) {
      if (!_jsonDeepEquals(actual[i], expected[i])) {
        return false;
      }
    }

    return true;
  }

  if (actual is Map<Object?, Object?> && expected is Map<Object?, Object?>) {
    if (actual.length != expected.length) {
      return false;
    }

    for (final MapEntry(:key, :value) in actual.entries) {
      if (!expected.containsKey(key) ||
          !_jsonDeepEquals(value, expected[key])) {
        return false;
      }
    }

    return true;
  }

  return actual == expected;
}
