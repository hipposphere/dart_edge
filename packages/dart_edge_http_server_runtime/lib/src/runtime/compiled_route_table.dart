import 'dart:convert';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'compiled_route.dart';
import 'compiled_web_socket_route.dart';

final class CompiledRouteTable<TServices> {
  CompiledRouteTable._(this.routes, this.webSocketRoutes)
    : routesById = {for (final route in routes) route.routeId: route},
      webSocketRoutesById = {
        for (final route in webSocketRoutes) route.routeId: route,
      };

  final List<CompiledRoute<TServices>> routes;
  final Map<String, CompiledRoute<TServices>> routesById;
  final List<CompiledWebSocketRoute<TServices>> webSocketRoutes;
  final Map<String, CompiledWebSocketRoute<TServices>> webSocketRoutesById;

  String nativeManifestJson({JsonSchemaRegistry? schemaRegistry}) =>
      jsonEncode({
        'routes': [
          ...routes.map((route) => route.toNativeJson()),
          ...webSocketRoutes.map((route) => route.toNativeJson()),
        ],
        'schemas':
            schemaRegistry?.asMap() ?? const <String, Map<String, Object?>>{},
      });

  static CompiledRouteTable<TServices> fromRegistrations<TServices>(
    Iterable<RouteRegistration<TServices>> registrations,
  ) {
    final routes = <CompiledRoute<TServices>>[];
    final webSocketRoutes = <CompiledWebSocketRoute<TServices>>[];
    var index = 0;

    for (final registration in registrations) {
      final routeId = 'route_$index';
      index += 1;
      final compiledRoute = CompiledRoute.tryParse(registration, routeId);
      if (compiledRoute != null) {
        routes.add(compiledRoute);
        continue;
      }

      final compiledWebSocketRoute = CompiledWebSocketRoute.tryParse(
        registration,
        routeId,
      );
      if (compiledWebSocketRoute != null) {
        webSocketRoutes.add(compiledWebSocketRoute);
      }
    }

    return CompiledRouteTable<TServices>._(
      List.unmodifiable(routes),
      List.unmodifiable(webSocketRoutes),
    );
  }
}
