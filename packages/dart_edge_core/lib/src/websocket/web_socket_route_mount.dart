import '../router/route_definition.dart';
import 'web_socket_route_definition.dart';

/// Binds a WebSocket route definition to the endpoint where it is mounted.
final class WebSocketRouteMount<TServices>
    implements RouteDefinition<TServices> {
  const WebSocketRouteMount({required this.path, required this.route});

  /// Route path pattern, for example `/chat/<roomId>`.
  final String path;

  /// Reusable WebSocket route implementation.
  final WebSocketRouteDefinition<TServices> route;
}
