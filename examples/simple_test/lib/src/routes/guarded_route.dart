import 'dart:async';
import 'dart:io';

import 'package:dart_edge/dart_edge.dart';
import 'package:dart_edge_auth/dart_edge_auth.dart';

class GuardedRoute extends JsonRouteDefinition {
  @override
  Object get contract => RouteContract(
    method: .get,
    path: '/guarded',
    operationId: 'getGuarded',
    responses: ResponseSet(
      success: .json(),
      errors: [ErrorResponse.unauthorized(code: 'unauthorized')],
    ),
  );

  @override
  FutureOr<dynamic> handle(RequestContext<dynamic> ctx) {
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
