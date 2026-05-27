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
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .createUser(
            token: token,
            email: body['email']! as String,
            password: body['password']! as String,
            name: body['name']! as String,
            role: body['role'] as String?,
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
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .updateUser(
            token: requireToken(ctx),
            userId: body['userId']! as String,
            name: body['name'] as String?,
            email: body['email'] as String?,
            role: body['role'] as String?,
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
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .setRole(
            token: token,
            userId: body['userId']! as String,
            role: body['role']! as String,
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
