import 'dart:io';

import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

import '../services.dart';

final class RawRoute extends JsonRouteDefinition<Services, Object?> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: benchmarkRawPath,
    operationId: 'benchmarkRaw',
    responses: ResponseSet(
      success: ResponseSpec.json<Object?>(),
      errors: [ErrorResponse.unauthorized(code: 'unauthorized')],
    ),
  );

  @override
  Future<Object?> handle(RequestContext<Services> ctx) async {
    final email = ctx.requireAuthIdentity.email;
    if (email == null) {
      return RawResponse.json(
        status: HttpStatus.unauthorized,
        body: {'error': 'unauthorized'},
      );
    }

    return RawResponse.encoded(
      status: HttpStatus.ok,
      contentType: 'application/json; charset=utf-8',
      body: benchmarkRawResponseJson(email),
    );
  }
}
