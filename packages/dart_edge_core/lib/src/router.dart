import 'dart:async';

import 'context.dart';
import 'http.dart';
import 'web_socket.dart';

/// Result of evaluating one [Guard].
final class GuardResult {
  const GuardResult.allow() : response = null;

  const GuardResult.deny(this.response);

  /// Optional response used to short-circuit the request.
  final RawResponse? response;

  /// Whether request handling should continue.
  bool get isAllowed => response == null;
}

/// Typed authorization guard evaluated before a route handler runs.
abstract interface class Guard<TServices> {
  /// Returns `allow` to continue or `deny` with a response to short-circuit.
  FutureOr<GuardResult> authorize(RequestContext<TServices> ctx);
}

/// Closure-backed guard handler.
typedef GuardHandler<TServices> =
    FutureOr<GuardResult> Function(RequestContext<TServices> ctx);

/// Concrete [Guard] backed by a closure.
final class HandlerGuard<TServices> implements Guard<TServices> {
  HandlerGuard({
    required GuardHandler<TServices> handler,
    this.debugName,
  }) : _handler = handler;

  final GuardHandler<TServices> _handler;
  final String? debugName;

  @override
  FutureOr<GuardResult> authorize(RequestContext<TServices> ctx) {
    return _handler(ctx);
  }

  @override
  String toString() => debugName ?? 'HandlerGuard<$TServices>()';
}

/// Base interface for any route definition that can be registered on a
/// [Router].
abstract class RouteDefinition<TServices> {
  /// Metadata consumed by the runtime when the route is registered.
  Object get contract;
}

/// Base class for an HTTP route handled in Dart and dispatched by the runtime.
abstract class JsonRouteDefinition<TServices, TSuccess>
    implements RouteDefinition<TServices> {
  /// Handles one decoded request.
  FutureOr<TSuccess> handle(RequestContext<TServices> ctx);
}

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

/// Base class for the planned WebSocket route surface.
abstract class WebSocketRouteDefinition<TServices>
    implements RouteDefinition<TServices> {
  @override
  WebSocketContract get contract;

  /// Called when the socket is connected.
  FutureOr<void> onConnect(WebSocketContext<TServices> socket);
}

/// Convenience options for inline `Router.get`/`post`/`put` style handlers.
final class RouteOptions {
  const RouteOptions({
    this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
    this.params,
    this.query,
    this.headers,
    this.body,
    this.success,
    this.errors = const <ErrorResponse>[],
  });

  /// Optional stable identifier used in generated output and manifests.
  final String? operationId;

  /// Optional short summary for documentation.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated.
  final bool deprecated;

  /// Schema reference for decoded path parameters.
  final JsonSchemaRef<Object?>? params;

  /// Schema reference for decoded query parameters.
  final JsonSchemaRef<Object?>? query;

  /// Schema reference for decoded request headers.
  final JsonSchemaRef<Object?>? headers;

  /// Request body contract, if the route accepts a body.
  final RequestBody? body;

  /// Documented success response.
  final ResponseSpec? success;

  /// Documented non-success responses.
  final List<ErrorResponse> errors;

  RouteContract toRouteContract({
    required HttpMethod method,
    required String path,
    required String defaultOperationId,
  }) {
    return RouteContract(
      method: method,
      path: path,
      operationId: operationId ?? defaultOperationId,
      summary: summary,
      tags: List.unmodifiable(tags),
      deprecated: deprecated,
      params: params,
      query: query,
      headers: headers,
      body: body,
      responses: ResponseSet(
        success: success ?? ResponseSpec.json<Object?>(),
        errors: List.unmodifiable(errors),
      ),
    );
  }
}

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
  void register(RouteDefinition<TServices> route) {
    routeRegistry.register(
      prefix: prefix,
      tags: tags,
      guards: guards,
      route: route,
    );
  }

  /// Registers many route definitions.
  void registerAll(Iterable<RouteDefinition<TServices>> definitions) {
    for (final definition in definitions) {
      register(definition);
    }
  }

  /// Registers an inline `GET` handler.
  void get<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.get,
      path: path,
      options: options,
      handler: handler,
    );
  }

  /// Registers an inline `POST` handler.
  void post<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.post,
      path: path,
      options: options,
      handler: handler,
    );
  }

  /// Registers an inline `PUT` handler.
  void put<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.put,
      path: path,
      options: options,
      handler: handler,
    );
  }

  /// Registers an inline `PATCH` handler.
  void patch<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.patch,
      path: path,
      options: options,
      handler: handler,
    );
  }

  /// Registers an inline `DELETE` handler.
  void delete<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.delete,
      path: path,
      options: options,
      handler: handler,
    );
  }

  /// Registers an inline `HEAD` handler.
  void head<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.head,
      path: path,
      options: options,
      handler: handler,
    );
  }

  /// Registers an inline `OPTIONS` handler.
  void options<TSuccess>(
    String path, {
    RouteOptions options = const RouteOptions(),
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    _registerHttpRoute(
      method: HttpMethod.options,
      path: path,
      options: options,
      handler: handler,
    );
  }

  void _registerHttpRoute<TSuccess>({
    required HttpMethod method,
    required String path,
    required RouteOptions options,
    required JsonRouteHandler<TServices, TSuccess> handler,
  }) {
    register(
      HandlerJsonRouteDefinition<TServices, TSuccess>(
        contract: options.toRouteContract(
          method: method,
          path: path,
          defaultOperationId: _defaultOperationId(method: method, path: path),
        ),
        handler: handler,
      ),
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
    registrations.add(
      RouteRegistration(
        prefix: prefix,
        tags: tags,
        guards: guards,
        route: route,
      ),
    );
  }
}

/// One registered route together with inherited router metadata.
final class RouteRegistration<TServices> {
  RouteRegistration({
    required this.prefix,
    required List<String> tags,
    required List<Guard<TServices>> guards,
    required this.route,
  }) : tags = List<String>.unmodifiable(tags),
       guards = List<Guard<TServices>>.unmodifiable(guards);

  final String prefix;
  final List<String> tags;
  final List<Guard<TServices>> guards;
  final RouteDefinition<TServices> route;

  @override
  String toString() {
    final contract = route.contract;
    if (contract case final RouteContract contract) {
      final fullPath = joinRoutePath(prefix, contract.path);
      final parts = <String>[
        '${contract.method.name.toUpperCase()} $fullPath',
        'operationId: ${contract.operationId}',
        if (tags.isNotEmpty) 'tags: $tags',
        if (guards.isNotEmpty) 'guards: $guards',
        'route: $route',
      ];
      return 'RouteRegistration(${parts.join(', ')})';
    }

    return 'RouteRegistration(prefix: $prefix, tags: $tags, guards: $guards, route: $route)';
  }
}

String joinRoutePath(String prefix, String path) {
  final normalizedPrefix = normalizeRoutePath(prefix);
  final normalizedPath = normalizeRoutePath(path);

  if (normalizedPrefix == '/') {
    return normalizedPath;
  }
  if (normalizedPath == '/') {
    return normalizedPrefix;
  }

  return '$normalizedPrefix$normalizedPath';
}

String normalizeRoutePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty || trimmed == '/') {
    return '/';
  }

  final withoutTrailingSlash = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  return withoutTrailingSlash.startsWith('/')
      ? withoutTrailingSlash
      : '/$withoutTrailingSlash';
}
