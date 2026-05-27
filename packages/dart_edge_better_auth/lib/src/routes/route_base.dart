part of '../routes.dart';

abstract class _BetterAuthRoute<TServices>
    extends HttpRouteDefinition<TServices, Object?> {
  _BetterAuthRoute(this.auth);

  final DartEdgeBetterAuth<TServices> auth;

  Object errorResponse(RequestContext<TServices> ctx, Object error) {
    if (error case final BetterAuthApiException exception) {
      ctx.res.status(exception.status);
      return exception.toJson();
    }
    throw error;
  }

  String? bearerToken(RequestContext<TServices> ctx) {
    final header = ctx.req.header('authorization');
    if (header == null) {
      return null;
    }
    const prefix = 'Bearer ';
    if (!header.startsWith(prefix)) {
      return null;
    }
    return header.substring(prefix.length);
  }

  String requireToken(RequestContext<TServices> ctx) {
    final token = bearerToken(ctx) ?? _sessionCookie(ctx);
    if (token == null) {
      throw const BetterAuthApiException(
        status: 401,
        code: 'UNAUTHORIZED',
        message: 'Unauthorized',
      );
    }
    return token;
  }
}

void _setSessionCookie<TServices>(RequestContext<TServices> ctx, String token) {
  ctx.res.header(
    'set-cookie',
    'better-auth.session-token=$token; Path=/; HttpOnly; SameSite=Lax',
  );
}

String? _sessionCookie<TServices>(RequestContext<TServices> ctx) {
  final cookie = ctx.req.header('cookie');
  if (cookie == null) {
    return null;
  }
  for (final part in cookie.split(';')) {
    final trimmed = part.trim();
    const name = 'better-auth.session-token=';
    if (trimmed.startsWith(name)) {
      return trimmed.substring(name.length);
    }
  }
  return null;
}
