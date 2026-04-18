import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_benchmark_shared/dart_edge_benchmark_shared.dart';

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

    if (responseBody != scenario.expectedBody) {
      throw StateError(
        '${scenario.id} returned unexpected body for $uri.\n'
        'Expected: ${scenario.expectedBody}\n'
        'Actual:   $responseBody',
      );
    }
  } finally {
    client.close(force: true);
  }
}
