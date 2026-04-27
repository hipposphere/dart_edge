part of 'dart_edge_auth.dart';

final class _DartEdgeAuthRouteTable {
  _DartEdgeAuthRouteTable(Iterable<AuthNativeRouteDescriptor> routes)
    : routes = List<AuthNativeRouteDescriptor>.unmodifiable(routes);

  final List<AuthNativeRouteDescriptor> routes;

  late final Map<String, AuthNativeRouteDescriptor> _routesByOperationId = {
    for (final route in routes) route.operationId: route,
  };

  AuthNativeRouteDescriptor routeForOperation(DartEdgeAuthOperation operation) {
    final route = _routesByOperationId[operation.id];
    if (route == null) {
      throw StateError(_missingOperationMessage(operation));
    }
    return route;
  }

  AuthNativeRouteDescriptor routeForOperationId(String operationId) {
    final route = _routesByOperationId[operationId];
    if (route == null) {
      throw StateError(
        'No Better Auth route is registered for operationId "$operationId". '
        '${_registeredRoutesSummary()}',
      );
    }
    return route;
  }

  String _missingOperationMessage(DartEdgeAuthOperation operation) {
    final expectedPlugin = operation.pluginName;
    final pluginHint = expectedPlugin == null
        ? ''
        : ' Required Better Auth plugin: "$expectedPlugin".';
    return 'No Better Auth route is registered for operationId '
        '"${operation.id}".$pluginHint ${_registeredRoutesSummary()}';
  }

  String _registeredRoutesSummary() {
    if (routes.isEmpty) {
      return 'No routes are registered for this auth instance.';
    }

    final pluginNames = <String>{
      for (final route in routes)
        if (route.pluginName case final pluginName?) pluginName,
    }.toList()..sort();
    final operationIds = routes.map((route) => route.operationId).toList()
      ..sort();

    return 'Registered plugins: '
        '${pluginNames.isEmpty ? 'none' : pluginNames.join(', ')}. '
        'Registered operations: ${operationIds.join(', ')}.';
  }
}
