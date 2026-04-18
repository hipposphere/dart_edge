import 'dart:convert';

import '../contracts/http/json_schema_registry.dart';
import 'compiled_route.dart';
import 'route_registry.dart';

final class CompiledRouteTable<TServices> {
  CompiledRouteTable._(this.routes)
    : routesById = {for (final route in routes) route.routeId: route};

  final List<CompiledRoute<TServices>> routes;
  final Map<String, CompiledRoute<TServices>> routesById;

  String nativeManifestJson({JsonSchemaRegistry? schemaRegistry}) =>
      jsonEncode({
        'routes': routes
            .map((route) => route.toNativeJson())
            .toList(growable: false),
        'schemas':
            schemaRegistry?.asMap() ?? const <String, Map<String, Object?>>{},
      });

  static CompiledRouteTable<TServices> fromRegistrations<TServices>(
    Iterable<RouteRegistration<TServices>> registrations,
  ) {
    final routes = <CompiledRoute<TServices>>[];
    var index = 0;

    for (final registration in registrations) {
      final compiledRoute = CompiledRoute.tryParse(
        registration,
        'route_$index',
      );
      index += 1;
      if (compiledRoute != null) {
        routes.add(compiledRoute);
      }
    }

    return CompiledRouteTable<TServices>._(List.unmodifiable(routes));
  }
}
