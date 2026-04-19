import '../http/http_method.dart';
import '../http/route_contract.dart';
import 'guard.dart';
import 'handler_json_route_definition.dart';
import 'route_definition.dart';
import 'route_options.dart';
import 'route_path.dart';
import 'route_registry.dart';

/// Route registration surface shared by apps and nested route groups.
class Router<TServices> {
  Router({
    this.prefix = '',
    List<String>? tags,
    List<Guard<TServices>>? guards,
    RouteRegistry<TServices>? routeRegistry,
  }) : routeRegistry = routeRegistry ?? RouteRegistry<TServices>(),
       tags = List.unmodifiable(tags ?? const <String>[]),
       guards = List.unmodifiable(guards ?? <Guard<TServices>>[]);

  /// Prefix applied to every registered route.
  final String prefix;

  /// Shared route registry used by this router tree.
  final RouteRegistry<TServices> routeRegistry;

  /// Documentation tags associated with this router scope.
  final List<String> tags;

  /// Guard metadata associated with this router scope.
  final List<Guard<TServices>> guards;

  /// Creates a child router that shares the same registry under [childPrefix].
  Router<TServices> router(
    String childPrefix, {
    List<String>? tags,
    List<Guard<TServices>>? guards,
  }) {
    return Router<TServices>(
      prefix: '$prefix$childPrefix',
      routeRegistry: routeRegistry,
      tags: [...this.tags, ...?tags],
      guards: [...this.guards, ...?guards],
    );
  }

  /// Registers one route definition.
  void register(
    RouteDefinition<TServices> route, {
    List<Guard<TServices>>? guards,
  }) {
    routeRegistry.register(
      prefix: prefix,
      tags: tags,
      guards: [...this.guards, ...?guards],
      route: route,
    );
  }

  /// Registers many route definitions.
  void registerAll(
    Iterable<RouteDefinition<TServices>> definitions, {
    List<Guard<TServices>>? guards,
  }) {
    for (final definition in definitions) {
      register(definition, guards: guards);
    }
  }

  /// Registers an inline `GET` handler.
  void get<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.get,
      path: path,
      options: options,
      guards: guards,
      handler: handler,
    );
  }

  /// Registers an inline `POST` handler.
  void post<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.post,
      path: path,
      options: options,
      guards: guards,
      handler: handler,
    );
  }

  /// Registers an inline `PUT` handler.
  void put<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.put,
      path: path,
      options: options,
      guards: guards,
      handler: handler,
    );
  }

  /// Registers an inline `PATCH` handler.
  void patch<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.patch,
      path: path,
      options: options,
      guards: guards,
      handler: handler,
    );
  }

  /// Registers an inline `DELETE` handler.
  void delete<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.delete,
      path: path,
      options: options,
      guards: guards,
      handler: handler,
    );
  }

  /// Registers an inline `HEAD` handler.
  void head<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.head,
      path: path,
      options: options,
      guards: guards,
      handler: handler,
    );
  }

  /// Registers an inline `OPTIONS` handler.
  void options<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.options,
      path: path,
      options: options,
      guards: guards,
      handler: handler,
    );
  }

  void _registerHttpRoute<TSuccess>({
    required HttpMethod method,
    required String path,
    required RouteOptions options,
    List<Guard<TServices>>? guards,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    register(
      HandlerJsonRouteDefinition<TServices, TSuccess>(
        contract: RouteContract(
          method: method,
          path: path,
          options: _withDefaultOperationId(
            options,
            _defaultOperationId(method: method, path: path),
          ),
        ),
        handler: handler,
      ),
      guards: guards,
    );
  }

  RouteOptions _withDefaultOperationId(
    RouteOptions options,
    String defaultOperationId,
  ) {
    return RouteOptions(
      operationId: options.operationId ?? defaultOperationId,
      summary: options.summary,
      tags: options.tags,
      deprecated: options.deprecated,
      params: options.params,
      query: options.query,
      headers: options.headers,
      body: options.body,
      success: options.success,
      errors: options.errors,
    );
  }

  String _defaultOperationId({
    required HttpMethod method,
    required String path,
  }) {
    final fullPath = joinRoutePath(prefix, path);
    if (fullPath == '/') {
      return '${method.name}Root';
    }

    final words = <String>[];
    for (final segment
        in fullPath.split('/').where((segment) => segment.isNotEmpty)) {
      if (segment.startsWith('<') && segment.endsWith('>')) {
        final parameter = segment.substring(1, segment.length - 1);
        words.add('by');
        words.addAll(_segmentWords(parameter));
        continue;
      }

      if (segment.startsWith(':') && segment.length > 1) {
        final parameter = segment.substring(1);
        words.add('by');
        words.addAll(_segmentWords(parameter));
        continue;
      }

      words.addAll(_segmentWords(segment));
    }

    if (words.isEmpty) {
      return '${method.name}Root';
    }

    return method.name + words.map(_capitalize).join();
  }

  Iterable<String> _segmentWords(String segment) {
    final normalized = segment
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ');
    return normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase());
  }

  String _capitalize(String word) {
    if (word.isEmpty) {
      return word;
    }

    return '${word[0].toUpperCase()}${word.substring(1)}';
  }
}
