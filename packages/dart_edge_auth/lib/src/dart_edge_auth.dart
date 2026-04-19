import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'dart_edge_auth_config.dart';
import 'native/dart_edge_auth_native.dart';

part 'dart_edge_auth_api.dart';

/// Owns a native Better Auth instance and exposes its routes to Dart Edge.
///
/// Create one instance per configured auth backend, mount it on a [Router], and
/// call [dispose] when you are done with it.
final class DartEdgeAuth {
  DartEdgeAuth._(this.config, this._nativeInstance, this._routes);

  /// Creates a new native Better Auth instance from [config].
  factory DartEdgeAuth(DartEdgeAuthConfig config) {
    final nativeInstance = DartEdgeAuthNative.create(config);
    final routes = List<NativeRouteDefinition>.unmodifiable(
      DartEdgeAuthNative.listRoutes(nativeInstance.handle),
    );
    return DartEdgeAuth._(config, nativeInstance, routes);
  }

  /// Configuration used to initialize the native auth instance.
  final DartEdgeAuthConfig config;
  final NativeAuthInstance _nativeInstance;
  final List<NativeRouteDefinition> _routes;
  late final Map<String, NativeRouteDefinition> _routesByOperationId = {
    for (final route in _routes) route.operationId: route,
  };
  var _disposed = false;
  late final DartEdgeAuthApi api = DartEdgeAuthApi._(this);

  /// Registers all auth routes on [router].
  ///
  /// The generated routes already include [DartEdgeAuthConfig.basePath]. Mount
  /// them on the app itself or on a tag-only router. Do not add the same auth
  /// prefix again, or you will end up with paths like `/auth/auth/...`.
  void mount<TServices>(Router<TServices> router) {
    router.registerAll(routes<TServices>());
  }

  /// Returns the route definitions that proxy into the auth backend.
  List<RouteDefinition<TServices>> routes<TServices>() {
    _ensureActive();
    return _routes
        .map((route) => _DartEdgeAuthRoute<TServices>(auth: this, route: route))
        .toList(growable: false);
  }

  /// Releases the native auth instance.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _nativeInstance.dispose();
  }

  /// Handles one auth request for an already mounted native route.
  ///
  /// Most applications should not call this directly. It is used by the route
  /// definitions returned from [routes].
  RawResponse handle<TServices>(
    NativeRouteDefinition route,
    RequestContext<TServices> ctx,
  ) {
    final params = _readMap(ctx.req.paramsValue);
    final response = _send(
      method: route.method,
      path: _resolvePath(route.path, params),
      query: _readMap(ctx.req.queryValue),
      headers: _readMap(ctx.req.headerValue),
      body: ctx.req.bodyValue,
    );

    return RawResponse.encoded(
      status: response.status,
      contentType: response.contentType,
      body: response.body,
      headers: response.headers,
    );
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('DartEdgeAuth has already been disposed.');
    }
  }

  NativeAuthResponseData _send({
    required HttpMethod method,
    required String path,
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) {
    _ensureActive();
    return DartEdgeAuthNative.handleRequest(
      _nativeInstance.handle,
      method: method,
      path: path,
      query: _stringifyMap(query),
      headers: headers,
      body: _encodeBody(body),
    );
  }

  NativeRouteDefinition _routeForOperation(String operationId) {
    _ensureActive();
    final route = _routesByOperationId[operationId];
    if (route == null) {
      final hint = switch (operationId) {
        final id when id.startsWith('admin_') =>
          ' Enable the admin plugin with '
              '`admin: DartEdgeAuthAdminConfig()` in `DartEdgeAuthConfig`.',
        'sign_up_email' || 'sign_in_email' || 'sign_in_username' =>
          ' Check `enableEmailPassword` and `enableSignup` in '
              '`DartEdgeAuthConfig`.',
        'get_session' ||
        'get_session_post' ||
        'sign_out' ||
        'list_sessions' ||
        'revoke_session' ||
        'revoke_sessions' ||
        'revoke_other_sessions' =>
          ' Check `enableSessionManagement` in `DartEdgeAuthConfig`.',
        'forget_password' ||
        'reset_password' ||
        'reset_password_token' ||
        'change_password' ||
        'set_password' =>
          ' Check `enablePasswordManagement` in `DartEdgeAuthConfig`.',
        'list_accounts' || 'unlink_account' =>
          ' Check `enableAccountManagement` in `DartEdgeAuthConfig`.',
        _ => '',
      };
      throw StateError(
        'No Better Auth route is registered for operationId "$operationId".$hint',
      );
    }
    return route;
  }

  @override
  String toString() {
    return 'DartEdgeAuth(basePath: ${config.basePath}, routes: ${_routes.length}, '
        'disposed: $_disposed)';
  }
}

final class _DartEdgeAuthRoute<TServices>
    extends JsonRouteDefinition<TServices, RawResponse> {
  _DartEdgeAuthRoute({required this.auth, required this.route});

  final DartEdgeAuth auth;
  final NativeRouteDefinition route;

  @override
  RouteContract get contract => RouteContract(
    method: route.method,
    path: _runtimePath(route.path),
    options: RouteOptions(
      operationId: route.operationId,
      body: route.acceptsJsonBody ? RequestBody.jsonValue() : null,
      success: ResponseSpec.json<Object?>(),
    ),
  );

  @override
  RawResponse handle(RequestContext<TServices> ctx) {
    return auth.handle(route, ctx);
  }

  @override
  String toString() {
    return 'DartEdgeAuthRoute<$TServices>('
        '${route.method.name.toUpperCase()} ${_runtimePath(route.path)}, '
        'operationId: ${route.operationId}, jsonBody: ${route.acceptsJsonBody})';
  }
}

Map<String, String> _readMap(Object? value) => switch (value) {
  final Map<String, String> map => map,
  _ => const <String, String>{},
};

Uint8List? _encodeBody(Object? value) => switch (value) {
  null => null,
  final Uint8List bytes => bytes,
  final List<int> bytes => Uint8List.fromList(bytes),
  final String text => Uint8List.fromList(utf8.encode(text)),
  _ => Uint8List.fromList(utf8.encode(jsonEncode(value))),
};

Map<String, String> _stringifyMap(Map<String, Object?> value) => {
  for (final entry in value.entries)
    if (entry.value case final raw?)
      entry.key: switch (raw) {
        final String text => text,
        _ => '$raw',
      },
};

String _resolvePath(String template, Map<String, String> params) {
  var path = template;
  for (final entry in params.entries) {
    path = path.replaceAll('{${entry.key}}', entry.value);
  }
  return path;
}

String _runtimePath(String path) {
  return path.replaceAllMapped(
    RegExp(r'\{([^}]+)\}'),
    (match) => '<${match[1]!}>',
  );
}
