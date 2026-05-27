part of '../routes.dart';

final class _AdminBanUserRoute<TServices> extends _BetterAuthRoute<TServices> {
  _AdminBanUserRoute(super.auth);

  @override
  RouteOptions get options => _adminBanUserOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      final banExpires = body['banExpires'] as String?;
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .banUser(
            token: requireToken(ctx),
            userId: body['userId']! as String,
            banReason: body['banReason'] as String?,
            banExpires: banExpires == null ? null : DateTime.parse(banExpires),
          );
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminUnbanUserRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminUnbanUserRoute(super.auth);

  @override
  RouteOptions get options => _adminUnbanUserOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .unbanUser(
            token: requireToken(ctx),
            userId: body['userId']! as String,
          );
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminRemoveUserRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminRemoveUserRoute(super.auth);

  @override
  RouteOptions get options => _adminRemoveUserOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      return (await auth
              .storeFor(ctx.services)
              .gateways
              .admin
              .removeUser(
                token: requireToken(ctx),
                userId: body['userId']! as String,
              ))
          .toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _AdminSetUserPasswordRoute<TServices>
    extends _BetterAuthRoute<TServices> {
  _AdminSetUserPasswordRoute(super.auth);

  @override
  RouteOptions get options => _adminSetUserPasswordOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      return (await auth
              .storeFor(ctx.services)
              .gateways
              .admin
              .setUserPassword(
                token: requireToken(ctx),
                userId: body['userId']! as String,
                password: body['password']! as String,
              ))
          .toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}
