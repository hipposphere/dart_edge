part of '../routes.dart';

final class _AdminCreateUserRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminCreateUserRoute(super.auth);

  @override
  RouteOptions get options => _adminCreateUserOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final token = bearerToken(ctx) ?? _sessionCookie(ctx);
      if (token == null) {
        throw const BetterAuthApiException(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Unauthorized',
        );
      }
      final body = ctx.req.body<Map<String, Object?>>();
      final role = body['role'];
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .createUser(
            token: token,
            email: body['email']! as String,
            password: body['password']! as String,
            name: body['name']! as String,
            role: _roleValue(role),
          );
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminUpdateUserRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminUpdateUserRoute(super.auth);

  @override
  RouteOptions get options => _adminUpdateUserOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      final data = (body['data'] as Map<String, Object?>?) ?? body;
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .updateUser(
            token: requireToken(ctx),
            userId: body['userId']! as String,
            name: data['name'] as String?,
            email: data['email'] as String?,
            role: _roleValue(data['role']),
          );
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminSetRoleRoute<TServices> extends _BetterAuthRoute<TServices> {
  _AdminSetRoleRoute(super.auth);

  @override
  RouteOptions get options => _adminSetRoleOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final token = bearerToken(ctx) ?? _sessionCookie(ctx);
      if (token == null) {
        throw const BetterAuthApiException(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Unauthorized',
        );
      }
      final body = ctx.req.body<Map<String, Object?>>();
      final role = body['role'];
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .setRole(
            token: token,
            userId: body['userId']! as String,
            role: _roleValue(role)!,
          );
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminListUsersRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminListUsersRoute(super.auth);

  @override
  RouteOptions get options => _adminListUsersOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final token = bearerToken(ctx) ?? _sessionCookie(ctx);
      if (token == null) {
        throw const BetterAuthApiException(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Unauthorized',
        );
      }
      final limit = int.tryParse(ctx.req.queryParam('limit') ?? '') ?? 100;
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .listUsers(token: token, limit: limit);
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminGetUserRoute<TServices> extends _BetterAuthRoute<TServices> {
  _AdminGetUserRoute(super.auth);

  @override
  RouteOptions get options => _adminGetUserOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .getUser(token: requireToken(ctx), userId: ctx.req.queryParam('id')!);
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminListUserSessionsRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminListUserSessionsRoute(super.auth);

  @override
  RouteOptions get options => _adminListUserSessionsOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .listUserSessions(
            token: requireToken(ctx),
            userId: body['userId']! as String,
          );
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminHasPermissionRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminHasPermissionRoute(super.auth);

  @override
  RouteOptions get options => _adminHasPermissionOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      final rawPermissions = body['permissions'] ?? body['permission'];
      if (rawPermissions == null) {
        throw const BetterAuthApiException(
          status: 400,
          code: 'BAD_REQUEST',
          message: 'invalid permission check. no permission(s) were passed.',
        );
      }
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .hasPermission(
            token: bearerToken(ctx) ?? _sessionCookie(ctx),
            userId: body['userId'] as String?,
            role: body['role'] as String?,
            permissions: _permissionsMap(rawPermissions),
          );
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}
