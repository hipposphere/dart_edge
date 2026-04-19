import 'dart:async';

import 'web_socket_context.dart';
import 'web_socket_contract.dart';
import 'web_socket_route_definition.dart';

/// Signature for a closure-backed WebSocket route handler.
typedef WebSocketRouteHandler<TServices> =
    FutureOr<void> Function(WebSocketContext<TServices> socket);

/// Concrete [WebSocketRouteDefinition] backed by an inline handler.
final class HandlerWebSocketRouteDefinition<TServices>
    extends WebSocketRouteDefinition<TServices> {
  HandlerWebSocketRouteDefinition({
    required WebSocketContract contract,
    required WebSocketRouteHandler<TServices> handler,
  }) : _contract = contract,
       _handler = handler;

  final WebSocketContract _contract;
  final WebSocketRouteHandler<TServices> _handler;

  @override
  WebSocketContract get contract => _contract;

  @override
  FutureOr<void> onConnect(WebSocketContext<TServices> socket) =>
      _handler(socket);

  @override
  String toString() {
    return 'HandlerWebSocketRouteDefinition<$TServices>('
        'WS ${_contract.path}, '
        'operationId: ${_contract.operationId})';
  }
}
