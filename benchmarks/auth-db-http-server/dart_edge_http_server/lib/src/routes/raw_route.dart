import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';

import '../services.dart';

final class RawRoute extends JsonRouteDefinition<Services, Object?> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/bench/raw',
    options: RouteOptions(
      operationId: 'benchmarkRaw',
      success: ResponseSpec.json<Object?>(),
      errors: [ErrorResponse.unauthorized(code: 'unauthorized')],
    ),
  );

  @override
  Future<Object?> handle(RequestContext<Services> ctx) async {
    final email = ctx.requireAuthIdentity.email;
    if (email == null) {
      return ctx.res.code(HttpStatus.unauthorized).json({
        'error': 'unauthorized',
      });
    }

    return ctx.res
        .type('application/json; charset=utf-8')
        .send(jsonEncode({'email': email, 'value': 'raw benchmark value'}));
  }
}
