import 'dart:async';

import '../context/web_socket_context.dart';
import '../contracts/web_socket/web_socket_contract.dart';
import 'route_definition.dart';

/// Base class for the planned WebSocket route surface.
///
/// The contract types already live in the runtime package so generators and
/// applications can depend on a stable API while the transport wiring evolves.
abstract class WebSocketRouteDefinition<TServices>
    implements RouteDefinition<TServices> {
  @override
  WebSocketContract get contract;

  /// Called when the socket is connected.
  FutureOr<void> onConnect(WebSocketContext<TServices> socket);
}
