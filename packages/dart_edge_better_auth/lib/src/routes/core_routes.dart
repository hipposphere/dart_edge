part of '../routes.dart';

final class _SignUpEmailRoute<TServices> extends _BetterAuthRoute<TServices> {
  _SignUpEmailRoute(super.auth);

  @override
  RouteOptions get options => _signUpEmailOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .credentials
          .signUpEmail(
            email: body['email']! as String,
            password: body['password']! as String,
            name: body['name']! as String,
          );
      _setSessionCookie(ctx, result.token);
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _SignInEmailRoute<TServices> extends _BetterAuthRoute<TServices> {
  _SignInEmailRoute(super.auth);

  @override
  RouteOptions get options => _signInEmailOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    try {
      final body = ctx.req.body<Map<String, Object?>>();
      final result = await auth
          .storeFor(ctx.services)
          .gateways
          .credentials
          .signInEmail(
            email: body['email']! as String,
            password: body['password']! as String,
          );
      _setSessionCookie(ctx, result.token);
      return result.toJson();
    } catch (error) {
      return errorResponse(ctx, error);
    }
  }
}

final class _GetSessionRoute<TServices> extends _BetterAuthRoute<TServices> {
  _GetSessionRoute(super.auth);

  @override
  RouteOptions get options => _getSessionOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    final token = bearerToken(ctx) ?? _sessionCookie(ctx);
    if (token == null) {
      ctx.res.status(401);
      return {'code': 'UNAUTHORIZED', 'message': 'Unauthorized'};
    }
    final session = await auth
        .storeFor(ctx.services)
        .gateways
        .sessions
        .getSession(token);
    if (session == null) {
      ctx.res.status(401);
      return {'code': 'UNAUTHORIZED', 'message': 'Unauthorized'};
    }
    return session.toJson();
  }
}

final class _SignOutRoute<TServices> extends _BetterAuthRoute<TServices> {
  _SignOutRoute(super.auth);

  @override
  RouteOptions get options => _signOutOptions;

  @override
  Future<Object?> handle(RequestContext<TServices> ctx) async {
    final token = bearerToken(ctx) ?? _sessionCookie(ctx);
    if (token != null) {
      await auth.storeFor(ctx.services).gateways.sessions.signOut(token);
    }
    ctx.res.header(
      'set-cookie',
      'better-auth.session-token=; Path=/; HttpOnly; SameSite=Lax; '
          'Expires=Thu, 01 Jan 1970 00:00:00 GMT',
    );
    return const {'success': true};
  }
}
