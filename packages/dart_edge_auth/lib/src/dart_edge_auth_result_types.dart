part of 'dart_edge_auth.dart';

/// Typed result returned by email sign-up.
final class DartEdgeAuthSignUpResult implements JsonEncodable {
  const DartEdgeAuthSignUpResult({
    required this.token,
    required this.user,
    required this.response,
  });

  factory DartEdgeAuthSignUpResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    return DartEdgeAuthSignUpResult(
      token: json['token'] as String?,
      user: DartEdgeAuthUser.fromJson(_authObject(json, 'user')),
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthSignUpResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'token': JsonSchema.string(nullable: true),
      'user': DartEdgeAuthUser.jsonSchema,
    },
    required: <String>['token', 'user'],
    additionalProperties: false,
  );

  final String? token;
  final DartEdgeAuthUser user;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'user': user,
  };
}

/// Typed result returned by email sign-in.
final class DartEdgeAuthSignInResult implements JsonEncodable {
  const DartEdgeAuthSignInResult({
    required this.redirect,
    required this.token,
    required this.url,
    required this.user,
    required this.twoFactorRedirect,
    required this.response,
  });

  factory DartEdgeAuthSignInResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    final twoFactorRedirect = json['twoFactorRedirect'] == true;
    return DartEdgeAuthSignInResult(
      redirect: json['redirect'] as bool? ?? false,
      token: _authRequiredString(json, 'token'),
      url: json['url'] as String?,
      user: twoFactorRedirect
          ? null
          : DartEdgeAuthUser.fromJson(_authObject(json, 'user')),
      twoFactorRedirect: twoFactorRedirect,
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthSignInResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'redirect': JsonSchema.boolean(),
      'token': JsonSchema.string(),
      'url': JsonSchema.string(nullable: true),
      'user': DartEdgeAuthUser.jsonSchema,
      'twoFactorRedirect': JsonSchema.boolean(),
    },
    required: <String>['redirect', 'token', 'url'],
    additionalProperties: true,
  );

  final bool redirect;
  final String token;
  final String? url;
  final DartEdgeAuthUser? user;
  final bool twoFactorRedirect;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  bool get requiresTwoFactor => twoFactorRedirect;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'redirect': redirect,
    'token': token,
    'url': url,
    'user': ?user,
    if (twoFactorRedirect) 'twoFactorRedirect': true,
  };
}

/// Typed result returned by get-session.
final class DartEdgeAuthSessionResult implements JsonEncodable {
  const DartEdgeAuthSessionResult({
    required this.session,
    required this.user,
    required this.response,
  });

  factory DartEdgeAuthSessionResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    return DartEdgeAuthSessionResult(
      session: DartEdgeAuthSession.fromJson(_authObject(json, 'session')),
      user: DartEdgeAuthUser.fromJson(_authObject(json, 'user')),
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthSessionResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'session': DartEdgeAuthSession.jsonSchema,
      'user': DartEdgeAuthUser.jsonSchema,
    },
    required: <String>['session', 'user'],
    additionalProperties: false,
  );

  final DartEdgeAuthSession session;
  final DartEdgeAuthUser user;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'session': session,
    'user': user,
  };
}

/// Typed `{ user }` result used by admin user mutation endpoints.
final class DartEdgeAuthUserResult implements JsonEncodable {
  const DartEdgeAuthUserResult({required this.user, required this.response});

  factory DartEdgeAuthUserResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    return DartEdgeAuthUserResult(
      user: DartEdgeAuthUser.fromJson(
        _authObject(_authSuccessJsonObject(response), 'user'),
      ),
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthUserResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{'user': DartEdgeAuthUser.jsonSchema},
    required: <String>['user'],
    additionalProperties: false,
  );

  final DartEdgeAuthUser user;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'user': user};
}

/// Typed `{ session, user }` result used by impersonation endpoints.
final class DartEdgeAuthSessionUserResult implements JsonEncodable {
  const DartEdgeAuthSessionUserResult({
    required this.session,
    required this.user,
    required this.response,
  });

  factory DartEdgeAuthSessionUserResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    return DartEdgeAuthSessionUserResult(
      session: DartEdgeAuthSession.fromJson(_authObject(json, 'session')),
      user: DartEdgeAuthUser.fromJson(_authObject(json, 'user')),
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthSessionUserResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'session': DartEdgeAuthSession.jsonSchema,
      'user': DartEdgeAuthUser.jsonSchema,
    },
    required: <String>['session', 'user'],
    additionalProperties: false,
  );

  final DartEdgeAuthSession session;
  final DartEdgeAuthUser user;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'session': session,
    'user': user,
  };
}

/// Typed admin user list result.
final class DartEdgeAuthListUsersResult implements JsonEncodable {
  const DartEdgeAuthListUsersResult({
    required this.users,
    required this.total,
    required this.limit,
    required this.offset,
    required this.response,
  });

  factory DartEdgeAuthListUsersResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    return DartEdgeAuthListUsersResult(
      users: [
        for (final user in json['users']! as List<Object?>)
          DartEdgeAuthUser.fromJson(user! as Map<String, Object?>),
      ],
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthListUsersResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'users': JsonSchema.array(items: DartEdgeAuthUser.jsonSchema),
      'total': JsonSchema.integer(),
      'limit': JsonSchema.integer(),
      'offset': JsonSchema.integer(),
    },
    required: <String>['users', 'total', 'limit', 'offset'],
    additionalProperties: false,
  );

  final List<DartEdgeAuthUser> users;
  final int total;
  final int limit;
  final int offset;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'users': users,
    'total': total,
    'limit': limit,
    'offset': offset,
  };
}

/// Typed session list result.
final class DartEdgeAuthListSessionsResult implements JsonEncodable {
  const DartEdgeAuthListSessionsResult({
    required this.sessions,
    required this.response,
  });

  factory DartEdgeAuthListSessionsResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    _authEnsureSuccess(response);
    final body = response.jsonBody;
    final rawSessions = switch (body) {
      {'sessions': final List<Object?> sessions} => sessions,
      final List<Object?> sessions => sessions,
      _ => throw StateError('Auth response body does not contain sessions.'),
    };
    return DartEdgeAuthListSessionsResult(
      sessions: [
        for (final session in rawSessions)
          DartEdgeAuthSession.fromJson(session! as Map<String, Object?>),
      ],
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthListSessionsResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'sessions': JsonSchema.array(items: DartEdgeAuthSession.jsonSchema),
    },
    required: <String>['sessions'],
    additionalProperties: false,
  );

  final List<DartEdgeAuthSession> sessions;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'sessions': sessions};
}

/// Typed `{ status }` result.
final class DartEdgeAuthStatusResult implements JsonEncodable {
  const DartEdgeAuthStatusResult({
    required this.status,
    required this.message,
    required this.response,
  });

  factory DartEdgeAuthStatusResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    return DartEdgeAuthStatusResult(
      status: json['status'] as bool? ?? false,
      message: json['message'] as String?,
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthStatusResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'status': JsonSchema.boolean(),
      'message': JsonSchema.string(nullable: true),
    },
    required: <String>['status'],
    additionalProperties: false,
  );

  final bool status;
  final String? message;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  bool get ok => status;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'status': status,
    'message': ?message,
  };
}

/// Typed `{ success }` result.
final class DartEdgeAuthSuccessResult implements JsonEncodable {
  const DartEdgeAuthSuccessResult({
    required this.success,
    required this.message,
    required this.response,
  });

  factory DartEdgeAuthSuccessResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    return DartEdgeAuthSuccessResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthSuccessResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'success': JsonSchema.boolean(),
      'message': JsonSchema.string(nullable: true),
    },
    required: <String>['success'],
    additionalProperties: false,
  );

  final bool success;
  final String? message;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  bool get ok => success;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'success': success,
    'message': ?message,
  };
}

/// Typed permission check result.
final class DartEdgeAuthPermissionResult implements JsonEncodable {
  const DartEdgeAuthPermissionResult({
    required this.success,
    required this.error,
    required this.response,
  });

  factory DartEdgeAuthPermissionResult.fromResponse(
    DartEdgeAuthApiResponse response,
  ) {
    final json = _authSuccessJsonObject(response);
    return DartEdgeAuthPermissionResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      response: response,
    );
  }

  static const schemaId = 'DartEdgeAuthPermissionResult';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'success': JsonSchema.boolean(),
      'error': JsonSchema.string(nullable: true),
    },
    required: <String>['success'],
    additionalProperties: false,
  );

  final bool success;
  final String? error;

  /// Raw HTTP response for headers such as `set-cookie`.
  final DartEdgeAuthApiResponse response;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'success': success,
    'error': ?error,
  };
}

Map<String, Object?> _authObject(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  throw StateError('Auth response field "$key" is not a JSON object.');
}

Map<String, Object?> _authSuccessJsonObject(DartEdgeAuthApiResponse response) {
  _authEnsureSuccess(response);
  return response.jsonObject;
}

void _authEnsureSuccess(DartEdgeAuthApiResponse response) {
  if (!response.isSuccess) {
    throw DartEdgeAuthApiException(response);
  }
}
