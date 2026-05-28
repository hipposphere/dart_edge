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
      final banExpiresIn = body['banExpiresIn'] as int?;
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .admin
          .banUser(
            token: requireToken(ctx),
            userId: body['userId']! as String,
            banReason: body['banReason'] as String?,
            banExpires: switch ((banExpires, banExpiresIn)) {
              (final value?, _) => DateTime.parse(value),
              (_, final seconds?) => DateTime.now().toUtc().add(
                Duration(seconds: seconds),
              ),
              _ => null,
            },
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
      final password = body['password'] ?? body['newPassword'];
      return (await auth
              .storeFor(ctx.services)
              .gateways
              .admin
              .setUserPassword(
                token: requireToken(ctx),
                userId: body['userId']! as String,
                password: password! as String,
              ))
          .toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}
