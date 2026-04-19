import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_benchmark_runner/src/benchmark_scenarios.dart';
import 'package:dart_edge_benchmark_runner/src/scenario_validator.dart';
import 'package:test/test.dart';

void main() {
  group('validateScenario', () {
    test('accepts semantically equivalent JSON responses', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        expect(request.uri.path, BenchmarkScenario.pathParam.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write('{ "name": "Benchmark User", "id": "42" }');
        await request.response.close();
      });

      await validateScenario(
        uri: Uri.http(
          '${server.address.address}:${server.port}',
          BenchmarkScenario.pathParam.path,
        ),
        scenario: BenchmarkScenario.pathParam,
      );
    });

    test('sends and validates JSON through the echo scenario', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        expect(request.method, BenchmarkScenario.echo.method);
        expect(request.uri.path, BenchmarkScenario.echo.path);

        final requestBody = await utf8.decoder.bind(request).join();
        expect(
          jsonDecode(requestBody),
          equals({'message': 'Echo payload', 'count': 1, 'enabled': true}),
        );

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          '{ "enabled": true, "count": 1, "message": "Echo payload" }',
        );
        await request.response.close();
      });

      await validateScenario(
        uri: Uri.http(
          '${server.address.address}:${server.port}',
          BenchmarkScenario.echo.path,
        ),
        scenario: BenchmarkScenario.echo,
      );
    });
  });
}
