import 'dart:io';

import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

import '../services.dart';

final class DatabaseRoute extends JsonRouteDefinition<Services, Object?> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: benchmarkDatabasePath,
    operationId: 'benchmarkDatabase',
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

    final result = await ctx.services.database.execute(
      SqlStatement.named(
        'SELECT value FROM benchmark_values WHERE email = :email',
        {'email': email},
      ),
    );
    if (result.single['value'] != benchmarkDatabaseValue) {
      return RawResponse.json(
        status: HttpStatus.internalServerError,
        body: {'error': 'benchmark_row_missing'},
      );
    }

    return RawResponse.encoded(
      status: HttpStatus.ok,
      contentType: 'application/json; charset=utf-8',
      body: benchmarkDatabaseResponseJson(email),
    );
  }
}
