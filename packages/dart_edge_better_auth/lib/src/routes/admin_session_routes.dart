part of '../routes.dart';

final class _AdminRevokeUserSessionRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminRevokeUserSessionRoute(super.auth);

  @override
  RouteOptions get options => _adminRevokeUserSessionOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      return (await auth
              .storeFor(ctx.services)
              .gateways
              .admin
              .revokeUserSession(
                token: requireToken(ctx),
                sessionToken: body['sessionToken']! as String,
              ))
          .toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminRevokeUserSessionsRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminRevokeUserSessionsRoute(super.auth);

  @override
  RouteOptions get options => _adminRevokeUserSessionsOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      return (await auth
              .storeFor(ctx.services)
              .gateways
              .admin
              .revokeUserSessions(
                token: requireToken(ctx),
                userId: body['userId']! as String,
              ))
          .toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminImpersonateUserRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminImpersonateUserRoute(super.auth);

  @override
  RouteOptions get options => _adminImpersonateUserOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final adminToken = requireToken(ctx);
      final body = ctx.req.body<Map<String, Object?>>();
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .impersonateUser(
            token: adminToken,
            userId: body['userId']! as String,
          );
      _setAdminSessionCookie(ctx, adminToken);
      _setSessionCookie(ctx, result.session.token);
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}
