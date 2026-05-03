import 'dart:async';
import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

final class GuardedRoute extends HttpRouteDefinition<PostgresPool, dynamic> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'getGuarded',
    success: ResponseSpec.json(),
    errors: [ErrorResponse.unauthorized(code: 'unauthorized')],
  );

  @override
  FutureOr<dynamic> handle(RequestContext<PostgresPool> ctx) {
    final authIdentity = ctx.authIdentity;
    if (authIdentity == null) {
      return RawResponse.json(
        status: HttpStatus.unauthorized,
        body: {'error': 'unauthorized'},
      );
    } else {
      return 'This is a guarded route. Your email is ${authIdentity.email}';
    }
  }
}
