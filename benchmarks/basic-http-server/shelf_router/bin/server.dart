import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_benchmark_shared/dart_edge_benchmark_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Future<void> main(List<String> args) async {
  final port = parseBenchmarkPort(args);
  final router = Router()
    ..get(
      '/plaintext',
      (_) => Response.ok(
        benchmarkPlaintextBody,
        headers: const {
          HttpHeaders.contentTypeHeader: 'text/plain; charset=utf-8',
        },
      ),
    )
    ..get(
      '/json',
      (_) => Response.ok(
        jsonEncode(benchmarkJsonPayload),
        headers: const {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      ),
    )
    ..get(
      '/users/<id>',
      (_, String id) => Response.ok(
        jsonEncode(benchmarkUserPayload(id)),
        headers: const {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      ),
    )
    ..post('/echo', (Request request) async {
      final body = await request.readAsString();
      final payload = body.isEmpty ? benchmarkEchoPayload : jsonDecode(body);
      return Response.ok(
        jsonEncode(payload),
        headers: const {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      );
    });

  await shelf_io.serve(router.call, InternetAddress.loopbackIPv4, port);
}
