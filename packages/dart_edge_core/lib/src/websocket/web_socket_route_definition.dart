import 'dart:async';

import '../router/route_definition.dart';
import 'web_socket_context.dart';
import 'web_socket_contract.dart';

/// Base class for the planned WebSocket route surface.
abstract class WebSocketRouteDefinition<TServices>
    implements RouteDefinition<TServices> {
  @override
  WebSocketContract get contract;

  /// Called when the socket is connected.
  FutureOr<void> onConnect(WebSocketContext<TServices> socket);
}
