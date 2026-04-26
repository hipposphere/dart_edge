import '../http/http_method.dart';
import '../websocket/web_socket_route_definition.dart';
import '../websocket/web_socket_route_mount.dart';
import 'guard.dart';
import 'http_route_definition.dart';
import 'http_route_mount.dart';
import 'route_definition.dart';
import 'route_path.dart';

/// In-memory route registration table shared across router scopes.
final class RouteRegistry<TServices> {
  final List<RouteRegistration<TServices>> registrations =
      <RouteRegistration<TServices>>[];

  void register({
    required String prefix,
    required List<String> tags,
    required List<Guard<TServices>> guards,
    required RouteDefinition<TServices> route,
  }) {
    final normalized = _normalizeRoute(route);

    registrations.add(
      RouteRegistration(
        prefix: prefix,
        tags: tags,
        guards: guards,
        route: normalized.route,
        httpMethod: normalized.method,
        httpPath: normalized.path,
      ),
    );
  }

  ({Object route, HttpMethod? method, String? path}) _normalizeRoute(
    RouteDefinition<TServices> route,
  ) {
    return switch (route) {
      final HttpRouteMount<TServices, dynamic> mount => (
        route: mount.route,
        method: mount.method,
        path: mount.path,
      ),
      final WebSocketRouteMount<TServices> mount => (
        route: mount.route,
        method: null,
        path: mount.path,
      ),
      _ => throw ArgumentError.value(
        route,
        'route',
        'Route definitions must be mounted before registration.',
      ),
    };
  }
}

/// One registered route together with inherited router metadata.
final class RouteRegistration<TServices> {
  RouteRegistration({
    required this.prefix,
    required List<String> tags,
    required List<Guard<TServices>> guards,
    required this.route,
    this.httpMethod,
    this.httpPath,
  }) : tags = List<String>.unmodifiable(tags),
       guards = List<Guard<TServices>>.unmodifiable(guards);

  final String prefix;
  final List<String> tags;
  final List<Guard<TServices>> guards;
  final Object route;
  final HttpMethod? httpMethod;
  final String? httpPath;

  @override
  String toString() {
    switch (route) {
      case final HttpRouteDefinition<TServices, dynamic> route:
        final method = httpMethod;
        final path = httpPath;
        if (method == null || path == null) {
          return 'RouteRegistration(prefix: $prefix, tags: $tags, guards: $guards, route: $route)';
        }
        final fullPath = joinRoutePath(prefix, path);
        final options = route.options.normalized();
        final routeTags = _mergeTags(tags, options.tags);
        final parts = <String>[
          '${method.name.toUpperCase()} $fullPath',
          'operationId: ${options.operationId!}',
          if (routeTags.isNotEmpty) 'tags: $routeTags',
          if (guards.isNotEmpty) 'guards: $guards',
          'route: $route',
        ];
        return 'RouteRegistration(${parts.join(', ')})';
      case final WebSocketRouteDefinition<TServices> route:
        final path = httpPath;
        if (path == null) {
          return 'RouteRegistration(prefix: $prefix, tags: $tags, guards: $guards, route: $route)';
        }
        final fullPath = joinRoutePath(prefix, path);
        final options = route.options.normalized();
        final routeTags = _mergeTags(tags, options.tags);
        final parts = <String>[
          'WS $fullPath',
          'operationId: ${options.operationId}',
          if (routeTags.isNotEmpty) 'tags: $routeTags',
          if (guards.isNotEmpty) 'guards: $guards',
          'route: $route',
        ];
        return 'RouteRegistration(${parts.join(', ')})';
      default:
        return 'RouteRegistration(prefix: $prefix, tags: $tags, guards: $guards, route: $route)';
    }
  }
}

List<String> _mergeTags(Iterable<String> first, Iterable<String> second) {
  final merged = <String>[];
  final seen = <String>{};
  for (final tag in [...first, ...second]) {
    if (seen.add(tag)) {
      merged.add(tag);
    }
  }
  return merged;
}
