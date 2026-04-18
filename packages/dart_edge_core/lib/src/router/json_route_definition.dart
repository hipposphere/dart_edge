import 'dart:async';

import '../context/request_context.dart';
import 'route_definition.dart';

/// Base class for an HTTP route handled in Dart and dispatched by the runtime.
abstract class JsonRouteDefinition<TServices, TSuccess>
    implements RouteDefinition<TServices> {
  /// Handles one decoded request.
  FutureOr<TSuccess> handle(RequestContext<TServices> ctx);
}
