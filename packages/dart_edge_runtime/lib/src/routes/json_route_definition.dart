import 'dart:async';

import '../context/request_context.dart';
import 'route_definition.dart';

/// Base class for an HTTP route handled in Dart and dispatched by the runtime.
///
/// Implement [contract] to describe the route shape and [handle] to produce the
/// response body. Return [RawResponse] when you need to override the response
/// status, content type, or headers directly.
abstract class JsonRouteDefinition<TServices, TSuccess>
    implements RouteDefinition<TServices> {
  /// Handles one decoded request.
  FutureOr<TSuccess> handle(RequestContext<TServices> ctx);
}
