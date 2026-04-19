import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import 'load_result.dart';

/// Virtual-user benchmark driver for auth-sensitive scenarios.
final class VirtualUserRunner {
  const VirtualUserRunner();

  Future<void> validateScenario({
    required BenchmarkScenario scenario,
    required Uri baseUri,
  }) async {
    final email = benchmarkFlowUserEmail(0);
    final forwardedFor = _workerForwardedFor(0);

    switch (scenario) {
      case BenchmarkScenario.signIn:
        await _signIn(
          baseUri: baseUri,
          email: email,
          forwardedFor: forwardedFor,
        );
        return;
      case BenchmarkScenario.rawAuthed:
        final bearerToken = await _signIn(
          baseUri: baseUri,
          email: email,
          forwardedFor: forwardedFor,
        );
        await _authorizedGet(
          uri: baseUri.resolve(benchmarkRawPath),
          bearerToken: bearerToken,
          expectedBody: benchmarkRawResponseJson(email),
          forwardedFor: forwardedFor,
        );
        return;
      case BenchmarkScenario.dbAuthed:
        final bearerToken = await _signIn(
          baseUri: baseUri,
          email: email,
          forwardedFor: forwardedFor,
        );
        await _authorizedGet(
          uri: baseUri.resolve(benchmarkDatabasePath),
          bearerToken: bearerToken,
          expectedBody: benchmarkDatabaseResponseJson(email),
          forwardedFor: forwardedFor,
        );
        return;
      case BenchmarkScenario.flow:
        final bearerToken = await _signIn(
          baseUri: baseUri,
          email: email,
          forwardedFor: forwardedFor,
        );
        await _authorizedGet(
          uri: baseUri.resolve(benchmarkRawPath),
          bearerToken: bearerToken,
          expectedBody: benchmarkRawResponseJson(email),
          forwardedFor: forwardedFor,
        );
        await _authorizedGet(
          uri: baseUri.resolve(benchmarkDatabasePath),
          bearerToken: bearerToken,
          expectedBody: benchmarkDatabaseResponseJson(email),
          forwardedFor: forwardedFor,
        );
        return;
    }
  }

  Future<ScenarioLoadResult> runScenario({
    required BenchmarkScenario scenario,
    required Uri baseUri,
    required Duration duration,
    int concurrency = 1,
  }) async {
    final latenciesMs = <double>[];
    final stopwatch = Stopwatch()..start();
    final deadline = DateTime.now().add(duration);
    var operations = 0;
    var errors = 0;
    String? firstError;

    await Future.wait(
      List.generate(
        concurrency,
        (workerIndex) => _runWorker(
          scenario: scenario,
          workerIndex: workerIndex,
          baseUri: baseUri,
          deadline: deadline,
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
    required BenchmarkScenario scenario,
    required int workerIndex,
    required Uri baseUri,
    required DateTime deadline,
    required List<double> latenciesMs,
    required void Function() onSuccess,
    required void Function(String error) onError,
  }) async {
    final userIndex = workerIndex % benchmarkFlowUserCount;
    final email = benchmarkFlowUserEmail(userIndex);
    final forwardedFor = _workerForwardedFor(workerIndex);
    String? bearerToken;

    if (scenario
        case BenchmarkScenario.rawAuthed || BenchmarkScenario.dbAuthed) {
      try {
        bearerToken = await _signIn(
          baseUri: baseUri,
          email: email,
          forwardedFor: forwardedFor,
        );
      } catch (error) {
        onError(error.toString());
      }
    }

    while (DateTime.now().isBefore(deadline)) {
      final started = Stopwatch()..start();

      try {
        switch (scenario) {
          case BenchmarkScenario.signIn:
            await _signIn(
              baseUri: baseUri,
              email: email,
              forwardedFor: forwardedFor,
            );
            break;
          case BenchmarkScenario.rawAuthed:
            bearerToken ??= await _signIn(
              baseUri: baseUri,
              email: email,
              forwardedFor: forwardedFor,
            );
            await _authorizedGet(
              uri: baseUri.resolve(benchmarkRawPath),
              bearerToken: bearerToken,
              expectedBody: benchmarkRawResponseJson(email),
              forwardedFor: forwardedFor,
            );
            break;
          case BenchmarkScenario.dbAuthed:
            bearerToken ??= await _signIn(
              baseUri: baseUri,
              email: email,
              forwardedFor: forwardedFor,
            );
            await _authorizedGet(
              uri: baseUri.resolve(benchmarkDatabasePath),
              bearerToken: bearerToken,
              expectedBody: benchmarkDatabaseResponseJson(email),
              forwardedFor: forwardedFor,
            );
            break;
          case BenchmarkScenario.flow:
            final flowToken = await _signIn(
              baseUri: baseUri,
              email: email,
              forwardedFor: forwardedFor,
            );
            await _authorizedGet(
              uri: baseUri.resolve(benchmarkRawPath),
              bearerToken: flowToken,
              expectedBody: benchmarkRawResponseJson(email),
              forwardedFor: forwardedFor,
            );
            await _authorizedGet(
              uri: baseUri.resolve(benchmarkDatabasePath),
              bearerToken: flowToken,
              expectedBody: benchmarkDatabaseResponseJson(email),
              forwardedFor: forwardedFor,
            );
            break;
        }

        started.stop();
        latenciesMs.add(started.elapsedMicroseconds / 1000);
        onSuccess();
      } catch (error) {
        started.stop();
        if (scenario
            case BenchmarkScenario.rawAuthed || BenchmarkScenario.dbAuthed) {
          bearerToken = null;
        }
        onError(error.toString());
      }
    }
  }

  Future<String> _signIn({
    required Uri baseUri,
    required String email,
    required String forwardedFor,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

    try {
      final request = await client.postUrl(
        baseUri.resolve('/auth/sign-in/email'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set('origin', baseUri.origin);
      request.headers.set('x-forwarded-for', forwardedFor);
      request.write('{"email":"$email","password":"$benchmarkUserPassword"}');

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw StateError('sign_in returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, Object?>) {
        throw StateError('sign_in returned a non-object response.');
      }

      final user = decoded['user'];
      if (user is! Map || user['email'] != email) {
        throw StateError('sign_in returned the wrong user payload.');
      }

      final token = decoded['token'];
      if (token is! String || token.isEmpty) {
        throw StateError('sign_in did not return a token.');
      }

      return token;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _authorizedGet({
    required Uri uri,
    required String? bearerToken,
    required String expectedBody,
    required String forwardedFor,
  }) async {
    if (bearerToken == null) {
      throw StateError('Missing bearer token for $uri.');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

    try {
      final request = await client.getUrl(uri);
      request.headers.set('authorization', 'Bearer $bearerToken');
      request.headers.set('x-forwarded-for', forwardedFor);

      final response = await request.close();
      final contentType = response.headers.contentType?.toString() ?? '';
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw StateError('GET $uri returned ${response.statusCode}.');
      }
      if (!contentType.contains('application/json')) {
        throw StateError('GET $uri returned "$contentType".');
      }
      if (responseBody != expectedBody) {
        throw StateError(
          'GET $uri returned an unexpected body.\n'
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

String _workerForwardedFor(int workerIndex) {
  final thirdOctet = (workerIndex ~/ 254) % 255;
  final fourthOctet = (workerIndex % 254) + 1;
  return '198.18.$thirdOctet.$fourthOctet';
}
