import 'dart:convert';
import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';

import '../services.dart';

final class RawRoute extends HttpRouteDefinition<Services, Object?> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'benchmarkRaw',
    success: ResponseSpec.json(),
    errors: [ErrorResponse.unauthorized(code: 'unauthorized')],
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
