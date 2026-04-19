import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import 'load_result.dart';

/// Concurrent benchmark driver for the end-to-end sign-in -> raw -> db flow.
final class FlowRunner {
  const FlowRunner();

  Future<ScenarioLoadResult> runScenario({
    required Uri baseUri,
    required Duration duration,
    int concurrency = 1,
  }) async {
    final latenciesMs = <double>[];
    final stopwatch = Stopwatch()..start();
    final deadline = DateTime.now().add(duration);
    var operations = 0;
    var errors = 0;
    var nextUserIndex = 0;
    String? firstError;

    int allocateUserIndex() {
      final userIndex = nextUserIndex % benchmarkFlowUserCount;
      nextUserIndex += 1;
      return userIndex;
    }

    await Future.wait(
      List.generate(
        concurrency,
        (index) => _runWorker(
          workerIndex: index,
          baseUri: baseUri,
          deadline: deadline,
          allocateUserIndex: allocateUserIndex,
          latenciesMs: latenciesMs,
          onSuccess: () {
            operations += 1;
          },
          onError: (error) {
            errors += 1;
            firstError ??= error;
          },
        ),
      ),
    );

    stopwatch.stop();

    if (latenciesMs.isEmpty) {
      return ScenarioLoadResult(
        operations: operations,
        errors: errors,
        operationsPerSecond: 0,
        averageLatencyMs: 0,
        p50LatencyMs: 0,
        p90LatencyMs: 0,
        p99LatencyMs: 0,
        maxLatencyMs: 0,
        firstError: firstError,
      );
    }

    latenciesMs.sort();
    final totalLatencyMs = latenciesMs.fold<double>(
      0,
      (sum, item) => sum + item,
    );

    return ScenarioLoadResult(
      operations: operations,
      errors: errors,
      operationsPerSecond:
          operations /
          (stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond),
      averageLatencyMs: totalLatencyMs / latenciesMs.length,
      p50LatencyMs: _percentile(latenciesMs, 0.50),
      p90LatencyMs: _percentile(latenciesMs, 0.90),
      p99LatencyMs: _percentile(latenciesMs, 0.99),
      maxLatencyMs: latenciesMs.last,
      firstError: firstError,
    );
  }

  Future<void> _runWorker({
    required int workerIndex,
    required Uri baseUri,
    required DateTime deadline,
    required int Function() allocateUserIndex,
    required List<double> latenciesMs,
    required void Function() onSuccess,
    required void Function(String error) onError,
  }) async {
    while (DateTime.now().isBefore(deadline)) {
      final started = Stopwatch()..start();

      try {
        final email = benchmarkFlowUserEmail(allocateUserIndex());
        final bearerToken = await _signIn(baseUri: baseUri, email: email);
        await _authorizedGet(
          uri: baseUri.resolve(benchmarkRawPath),
          bearerToken: bearerToken,
          expectedBody: benchmarkRawResponseJson(email),
        );
        await _authorizedGet(
          uri: baseUri.resolve(benchmarkDatabasePath),
          bearerToken: bearerToken,
          expectedBody: benchmarkDatabaseResponseJson(email),
        );

        started.stop();
        latenciesMs.add(started.elapsedMicroseconds / 1000);
        onSuccess();
      } catch (error) {
        onError(error.toString());
      }
    }
  }

  Future<String> _signIn({required Uri baseUri, required String email}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

    try {
      final request = await client.postUrl(
        baseUri.resolve('/auth/sign-in/email'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set('origin', baseUri.origin);
      request.write('{"email":"$email","password":"$benchmarkUserPassword"}');

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Flow sign_in returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, Object?>) {
        throw StateError('Flow sign_in returned a non-object response.');
      }

      final user = decoded['user'];
      if (user is! Map || user['email'] != email) {
        throw StateError('Flow sign_in returned the wrong user payload.');
      }

      final token = decoded['token'];
      if (token is! String || token.isEmpty) {
        throw StateError('Flow sign_in did not return a token.');
      }

      return token;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _authorizedGet({
    required Uri uri,
    required String bearerToken,
    required String expectedBody,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

    try {
      final request = await client.getUrl(uri);
      request.headers.set('authorization', 'Bearer $bearerToken');

      final response = await request.close();
      final contentType = response.headers.contentType?.toString() ?? '';
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Flow GET $uri returned ${response.statusCode}.');
      }
      if (!contentType.contains('application/json')) {
        throw StateError('Flow GET $uri returned "$contentType".');
      }
      if (responseBody != expectedBody) {
        throw StateError(
          'Flow GET $uri returned an unexpected body.\n'
          'Expected: $expectedBody\n'
          'Actual:   $responseBody',
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}

double _percentile(List<double> sortedValues, double percentile) {
  if (sortedValues.isEmpty) {
    return 0;
  }

  final index = ((sortedValues.length - 1) * percentile).round();
  return sortedValues[index];
}
