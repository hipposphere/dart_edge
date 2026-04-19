import 'dart:convert';
import 'dart:io';

import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

import '../benchmark_config.dart';
import '../services.dart';

final class DatabaseRoute extends JsonRouteDefinition<Services, Object?> {
  @override
  RouteContract get contract => RouteContract(
    method: HttpMethod.get,
    path: '/bench/db',
    options: RouteOptions(
      operationId: 'benchmarkDatabase',
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

    final result = await ctx.services.database.execute(
      SqlStatement.named(
        'SELECT value FROM benchmark_values WHERE email = :email',
        {'email': email},
      ),
    );
    final value = result.single['value'];
    if (value is! String || value != benchmarkDatabaseValue) {
      return ctx.res.code(HttpStatus.internalServerError).json({
        'error': 'benchmark_row_missing',
      });
    }

    return ctx.res
        .type('application/json; charset=utf-8')
        .send(jsonEncode({'email': email, 'value': value}));
  }
}
