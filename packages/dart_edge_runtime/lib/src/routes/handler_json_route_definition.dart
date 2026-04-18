import 'dart:async';

import '../context/request_context.dart';
import '../contracts/http/route_contract.dart';
import 'json_route_definition.dart';

/// Signature for a closure-backed JSON route handler.
typedef JsonRouteHandler<TServices, TSuccess> =
    FutureOr<TSuccess> Function(RequestContext<TServices> ctx);

/// Concrete [JsonRouteDefinition] backed by an inline [JsonRouteHandler].
final class HandlerJsonRouteDefinition<TServices, TSuccess>
    extends JsonRouteDefinition<TServices, TSuccess> {
  HandlerJsonRouteDefinition({
    required RouteContract contract,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) : _contract = contract,
       _handler = handler;

  final RouteContract _contract;
  final JsonRouteHandler<TServices, TSuccess> _handler;

  @override
  RouteContract get contract => _contract;

  @override
  FutureOr<TSuccess> handle(RequestContext<TServices> ctx) => _handler(ctx);

  @override
  String toString() {
    return 'HandlerJsonRouteDefinition<$TServices, $TSuccess>('
        '${_contract.method.name.toUpperCase()} ${_contract.path}, '
        'operationId: ${_contract.operationId})';
  }
}
