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

void _setAdminSessionCookie<TServices>(
  RequestContext<TServices> ctx,
  String token,
) {
  ctx.res.header(
    'set-cookie',
    'better-auth.admin_session=$token; Path=/; HttpOnly; SameSite=Lax',
  );
}

void _clearAdminSessionCookie<TServices>(RequestContext<TServices> ctx) {
  ctx.res.header(
    'set-cookie',
    'better-auth.admin_session=; Path=/; HttpOnly; SameSite=Lax; '
        'Expires=Thu, 01 Jan 1970 00:00:00 GMT',
  );
}

String? _sessionCookie<TServices>(RequestContext<TServices> ctx) {
  return _cookie(ctx, 'better-auth.session-token');
}

String? _adminSessionCookie<TServices>(RequestContext<TServices> ctx) {
  return _cookie(ctx, 'better-auth.admin_session');
}

String? _roleValue(Object? value) {
  if (value == null) {
    return null;
  }
  try {
    return BetterAuthRoleInput.decode(value).commaSeparated;
  } on FormatException {
    throw const BetterAuthApiException(
      status: 400,
      code: 'INVALID_ROLE_TYPE',
      message: 'Invalid role type',
    );
  }
}

Map<String, List<String>> _permissionsMap(Object? value) {
  final map = value! as Map<String, Object?>;
  return map.map(
    (key, value) => MapEntry(key, switch (value) {
      final List<Object?> values => values.cast<String>(),
      _ => throw const BetterAuthApiException(
        status: 400,
        code: 'BAD_REQUEST',
        message: 'Invalid permission check.',
      ),
    }),
  );
}

String? _cookie<TServices>(RequestContext<TServices> ctx, String name) {
  final cookie = ctx.req.header('cookie');
  if (cookie == null) {
    return null;
  }
  for (final part in cookie.split(';')) {
    final trimmed = part.trim();
    final prefix = '$name=';
    if (trimmed.startsWith(prefix)) {
      return trimmed.substring(prefix.length);
    }
  }
  return null;
}
