import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Future<void> main(List<String> args) async {
  final port = _parsePort(args);
  final router = Router()
    ..get(
      '/plaintext',
      (_) => Response.ok(
        'Hello, World!',
        headers: const {
          HttpHeaders.contentTypeHeader: 'text/plain; charset=utf-8',
        },
      ),
    )
    ..get(
      '/json',
      (_) => Response.ok(
        jsonEncode({'message': 'Hello, World!'}),
        headers: const {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      ),
    )
    ..get(
      '/users/<id>',
      (_, String id) => Response.ok(
        jsonEncode({'id': id, 'name': 'Benchmark User'}),
        headers: const {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      ),
    )
    ..post('/echo', (Request request) async {
      final body = await request.readAsString();
      final payload = body.isEmpty
          ? {'message': 'Echo payload', 'count': 1, 'enabled': true}
          : jsonDecode(body);
      return Response.ok(
        jsonEncode(payload),
        headers: const {
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      );
    });

  await shelf_io.serve(router.call, InternetAddress.loopbackIPv4, port);
}

int _parsePort(List<String> args, {int defaultPort = 8080}) {
  for (final argument in args) {
    if (argument.startsWith('--port=')) {
      return int.parse(argument.substring('--port='.length));
    }
  }

  return defaultPort;
}
