import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'dart_edge_auth_config.dart';
import 'generated/dart_edge_auth_tables.g.dart';
import 'models/model_helpers.dart';
import 'models/session.dart';
import 'models/user.dart';
import 'native/dart_edge_auth_native.dart';

export 'generated/dart_edge_auth_tables.g.dart';
export 'models/session.dart';
export 'models/user.dart';

part 'dart_edge_auth_schema.dart';
part 'dart_edge_auth_api_types.dart';
part 'dart_edge_auth_api.dart';
part 'dart_edge_auth_admin_api.dart';
part 'dart_edge_auth_trusted_admin_api.dart';
part 'dart_edge_auth_result_types.dart';
part 'dart_edge_auth_api_response.dart';
part 'dart_edge_auth_route_table.dart';
part 'dart_edge_auth_worker_pool.dart';

/// Compile-time token for a Better Auth operation exposed by Dart Edge Auth.
final class DartEdgeAuthOperation {
  const DartEdgeAuthOperation._(this.id, {this.pluginName});

  /// Better Auth operation id.
  final String id;

  /// Better Auth plugin that contributes this route, when plugin-owned.
  final String? pluginName;

  static const signUpEmail = DartEdgeAuthOperation._(
    'sign_up_email',
    pluginName: 'email-password',
  );
  static const signInEmail = DartEdgeAuthOperation._(
    'sign_in_email',
    pluginName: 'email-password',
  );
  static const getSession = DartEdgeAuthOperation._(
    'get_session',
    pluginName: 'session-management',
  );
  static const getSessionPost = DartEdgeAuthOperation._(
    'get_session_post',
    pluginName: 'session-management',
  );
  static const signOut = DartEdgeAuthOperation._(
    'sign_out',
    pluginName: 'session-management',
  );
  static const updateUser = DartEdgeAuthOperation._('update_user');
  static const changeEmail = DartEdgeAuthOperation._('change_email');
  static const adminSetRole = DartEdgeAuthOperation._(
    'admin_set_role',
    pluginName: 'admin',
  );
  static const adminCreateUser = DartEdgeAuthOperation._(
    'admin_create_user',
    pluginName: 'admin',
  );
  static const adminListUsers = DartEdgeAuthOperation._(
    'admin_list_users',
    pluginName: 'admin',
  );
  static const adminListUserSessions = DartEdgeAuthOperation._(
    'admin_list_user_sessions',
    pluginName: 'admin',
  );
  static const adminBanUser = DartEdgeAuthOperation._(
    'admin_ban_user',
    pluginName: 'admin',
  );
  static const adminUnbanUser = DartEdgeAuthOperation._(
    'admin_unban_user',
    pluginName: 'admin',
  );
  static const adminImpersonateUser = DartEdgeAuthOperation._(
    'admin_impersonate_user',
    pluginName: 'admin',
  );
  static const adminStopImpersonating = DartEdgeAuthOperation._(
    'admin_stop_impersonating',
    pluginName: 'admin',
  );
  static const adminRevokeUserSession = DartEdgeAuthOperation._(
    'admin_revoke_user_session',
    pluginName: 'admin',
  );
  static const adminRevokeUserSessions = DartEdgeAuthOperation._(
    'admin_revoke_user_sessions',
    pluginName: 'admin',
  );
  static const adminRemoveUser = DartEdgeAuthOperation._(
    'admin_remove_user',
    pluginName: 'admin',
  );
  static const adminSetUserPassword = DartEdgeAuthOperation._(
    'admin_set_user_password',
    pluginName: 'admin',
  );
  static const adminHasPermission = DartEdgeAuthOperation._(
    'admin_has_permission',
    pluginName: 'admin',
  );

  @override
  String toString() => id;
}

/// Owns a native Better Auth instance and exposes its routes to Dart Edge.
///
/// Create one instance per configured auth backend, mount it on a [Router], and
/// call [dispose] when you are done with it.
final class DartEdgeAuth {
  DartEdgeAuth._(
    this.config,
    this._nativeInstance,
    this._routeTable,
    this._workerPool,
  );

  /// Creates a new native Better Auth instance from [config].
  factory DartEdgeAuth(DartEdgeAuthConfig config) {
    final nativeInstance = DartEdgeAuthNative.create(config);
    final routes = List<AuthNativeRouteDescriptor>.unmodifiable(
      DartEdgeAuthNative.listRoutes(nativeInstance.handle),
    );
    return DartEdgeAuth._(
      config,
      nativeInstance,
      _DartEdgeAuthRouteTable(routes),
      _DartEdgeAuthWorkerPool(size: config.workerPoolSize),
    );
  }

  /// Configuration used to initialize the native auth instance.
  final DartEdgeAuthConfig config;
  final NativeAuthInstance _nativeInstance;
  final _DartEdgeAuthRouteTable _routeTable;
  final _DartEdgeAuthWorkerPool _workerPool;
  List<AuthNativeRouteDescriptor> get _routes => _routeTable.routes;
  var _disposed = false;
  late final DartEdgeAuthApi api = DartEdgeAuthApi._(this);
  late final DartEdgeAuthTrustedAdminApi trustedAdmin =
      DartEdgeAuthTrustedAdminApi._(this);

  /// Registers all auth routes on [router].
  ///
  /// The generated routes already include [DartEdgeAuthConfig.basePath]. Mount
  /// them on the app itself or below an application/router prefix. Do not add
  /// the same auth prefix again, or you will end up with paths like
  /// `/auth/auth/...`.
  void mount<TServices>(Router<TServices> router) {
    for (final route in routes<TServices>()) {
      router.mountHttpRoute(route);
    }
  }

  /// Registers all auth routes as native routes on [router].
  ///
  /// Native routes are served directly by the HTTP server runtime without
  /// crossing into Dart request handlers.
  void mountNative<TServices>(Router<TServices> router) {
    for (final route in nativeRoutes()) {
      router.mountNativeHttpRoute(route);
    }
  }

  /// Returns the mounted routes that proxy into the auth backend.
  List<HttpRouteMount<TServices, RawResponse>> routes<TServices>() {
    _ensureActive();
    return _routes
        .map(
          (route) => HttpRouteMount<TServices, RawResponse>(
            method: route.method,
            path: _runtimePath(route.path),
            route: _DartEdgeAuthRoute<TServices>(auth: this, route: route),
          ),
        )
        .toList(growable: false);
  }

  /// Returns native HTTP route mounts that proxy directly into Better Auth.
  List<NativeHttpRouteMount> nativeRoutes() {
    _ensureActive();
    return _routes
        .map(
          (route) => NativeHttpRouteMount(
            method: route.method,
            path: _runtimePath(route.path),
            handlerPath: _runtimePath(route.path),
            options: _routeOptions(route),
            nativeHandle: _nativeInstance.handle,
            nativeHandlerAddress: DartEdgeAuthNative.handleRequestAddress,
            nativeFreeResponseAddress: DartEdgeAuthNative.freeResponseAddress,
          ),
        )
        .toList(growable: false);
  }

  /// Releases the native auth instance.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _workerPool.close();
    _nativeInstance.dispose();
  }

  /// Handles one auth request for an already mounted native route.
  ///
  /// Most applications should not call this directly. It is used by the route
  /// definitions returned from [routes].
  RawResponse handle<TServices>(
    AuthNativeRouteDescriptor route,
    RequestContext<TServices> ctx,
  ) {
    final params = ctx.req.paramsMap;
    final response = _send(
      method: route.method,
      path: _resolvePath(route.path, params),
      query: ctx.req.queryMap,
      headers: ctx.req.headersMap,
      body: ctx.req.bodyOrNull,
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

  AuthNativeRouteDescriptor _routeForOperation(
    DartEdgeAuthOperation operation,
  ) {
    _ensureActive();
    return _routeTable.routeForOperation(operation);
  }

  AuthNativeRouteDescriptor _routeForOperationId(String operationId) {
    _ensureActive();
    return _routeTable.routeForOperationId(operationId);
  }

  @override
  String toString() {
    return 'DartEdgeAuth(basePath: ${config.basePath}, routes: ${_routes.length}, '
        'disposed: $_disposed)';
  }
}

final class _DartEdgeAuthRoute<TServices>
    extends HttpRouteDefinition<TServices, RawResponse> {
  _DartEdgeAuthRoute({required this.auth, required this.route});

  final DartEdgeAuth auth;
  final AuthNativeRouteDescriptor route;

  @override
  RouteOptions get options => _routeOptions(route);

  @override
  RawResponse handle(RequestContext<TServices> ctx) {
    return auth.handle(route, ctx);
  }

  @override
  String toString() {
    return 'DartEdgeAuthRoute<$TServices>('
        'operationId: ${route.operationId}, jsonBody: ${route.acceptsJsonBody})';
  }
}

RouteOptions _routeOptions(AuthNativeRouteDescriptor route) {
  return RouteOptions(
    operationId: route.operationId,
    body: route.acceptsJsonBody ? RequestBody.json() : null,
    success: ResponseSpec.json(schema: _successSchemaFor(route.operationId)),
  );
}

JsonSchema? _successSchemaFor(String operationId) {
  return switch (operationId) {
    'sign_up_email' => DartEdgeAuthSignUpResult.jsonSchema,
    'sign_in_email' => DartEdgeAuthSignInResult.jsonSchema,
    'get_session' || 'get_session_post' => DartEdgeAuthSessionResult.jsonSchema,
    'sign_out' => DartEdgeAuthSuccessResult.jsonSchema,
    'update_user' || 'change_email' => DartEdgeAuthStatusResult.jsonSchema,
    'admin_set_role' ||
    'admin_create_user' ||
    'admin_ban_user' ||
    'admin_unban_user' => DartEdgeAuthUserResult.jsonSchema,
    'admin_list_users' => DartEdgeAuthListUsersResult.jsonSchema,
    'admin_list_user_sessions' => DartEdgeAuthListSessionsResult.jsonSchema,
    'admin_impersonate_user' ||
    'admin_stop_impersonating' => DartEdgeAuthSessionUserResult.jsonSchema,
    'admin_revoke_user_session' ||
    'admin_revoke_user_sessions' ||
    'admin_remove_user' => DartEdgeAuthSuccessResult.jsonSchema,
    'admin_set_user_password' => DartEdgeAuthStatusResult.jsonSchema,
    'admin_has_permission' => DartEdgeAuthPermissionResult.jsonSchema,
    _ => null,
  };
}

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
