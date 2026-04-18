part of 'dart_edge_auth.dart';

typedef _AsyncAuthRequest = ({
  int handle,
  String method,
  String path,
  Map<String, String> query,
  Map<String, String> headers,
  Uint8List? body,
});

typedef _AsyncAuthResponse = ({
  int status,
  String contentType,
  List<({String name, String value})> headers,
  String body,
});

/// In-process Better Auth client for backend-side calls.
///
/// Async methods run on a background isolate so admin/user-management calls do
/// not block the caller's isolate while the native auth runtime performs work.
final class DartEdgeAuthApi {
  DartEdgeAuthApi._(
    this._auth, {
    Map<String, String> headers = const <String, String>{},
  }) : _headers = Map<String, String>.unmodifiable(headers);

  final DartEdgeAuth _auth;
  final Map<String, String> _headers;

  /// Current default headers applied to every call from this API instance.
  Map<String, String> get headers => _headers;

  /// Admin endpoints scoped to the same default headers.
  DartEdgeAuthAdminApi get admin => DartEdgeAuthAdminApi._(this);

  DartEdgeAuthApi withHeader(String name, String value) {
    return DartEdgeAuthApi._(_auth, headers: {..._headers, name: value});
  }

  DartEdgeAuthApi withHeaders(Map<String, String> headers) {
    return DartEdgeAuthApi._(_auth, headers: {..._headers, ...headers});
  }

  DartEdgeAuthApi withBearerToken(String token) {
    return withHeader('authorization', 'Bearer $token');
  }

  DartEdgeAuthApi withSessionToken(String token) {
    return withHeader('cookie', 'better-auth.session-token=$token');
  }

  DartEdgeAuthApi withOrigin(String origin) {
    return withHeader('origin', origin);
  }

  DartEdgeAuthApi withUserAgent(String userAgent) {
    return withHeader('user-agent', userAgent);
  }

  DartEdgeAuthApi withForwardedFor(String ipAddress) {
    return withHeader('x-forwarded-for', ipAddress);
  }

  /// Calls one Better Auth route directly through the native runtime.
  Future<DartEdgeAuthApiResponse> call({
    required HttpMethod method,
    required String path,
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async {
    final response = await Isolate.run(
      () => _performNativeAuthRequest(
        _requestForCall(
          method: method,
          path: path,
          query: query,
          headers: headers,
          body: body,
        ),
      ),
    );

    return _responseFromAsync(response);
  }

  /// Blocking version of [call].
  ///
  /// Prefer [call] unless you explicitly want to block the current isolate.
  DartEdgeAuthApiResponse callSync({
    required HttpMethod method,
    required String path,
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) {
    final request = _requestForCall(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
    return _responseFromAsync(_performNativeAuthRequest(request));
  }

  /// Calls one Better Auth route by [operationId].
  Future<DartEdgeAuthApiResponse> callOperation({
    required String operationId,
    Map<String, String> pathParams = const <String, String>{},
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) {
    final route = _auth._routeForOperation(operationId);
    return call(
      method: route.method,
      path: _resolvePath(route.path, pathParams),
      query: query,
      headers: headers,
      body: body,
    );
  }

  /// Blocking version of [callOperation].
  DartEdgeAuthApiResponse callOperationSync({
    required String operationId,
    Map<String, String> pathParams = const <String, String>{},
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) {
    final route = _auth._routeForOperation(operationId);
    return callSync(
      method: route.method,
      path: _resolvePath(route.path, pathParams),
      query: query,
      headers: headers,
      body: body,
    );
  }

  Future<DartEdgeAuthApiResponse> signUpEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    return (await callOperation(
      operationId: 'sign_up_email',
      body: {'email': email, 'password': password, 'name': name},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> signInEmail({
    required String email,
    required String password,
  }) async {
    return (await callOperation(
      operationId: 'sign_in_email',
      body: {'email': email, 'password': password},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> getSession({bool post = false}) async {
    return (await callOperation(
      operationId: post ? 'get_session_post' : 'get_session',
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> signOut() async {
    return (await callOperation(operationId: 'sign_out')).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> updateUser({
    String? email,
    String? name,
    String? image,
    String? username,
    String? displayUsername,
    String? role,
    Object? metadata,
  }) async {
    return (await callOperation(
      operationId: 'update_user',
      body: {
        if (email case final email?) 'email': email,
        if (name case final name?) 'name': name,
        if (image case final image?) 'image': image,
        if (username case final username?) 'username': username,
        if (displayUsername case final displayUsername?)
          'displayUsername': displayUsername,
        if (role case final role?) 'role': role,
        if (metadata case final metadata?) 'metadata': metadata,
      },
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> changeEmail({
    required String newEmail,
  }) async {
    return (await callOperation(
      operationId: 'change_email',
      body: {'newEmail': newEmail},
    )).requireSuccess();
  }

  _AsyncAuthRequest _requestForCall({
    required HttpMethod method,
    required String path,
    required Map<String, Object?> query,
    required Map<String, String> headers,
    required Object? body,
  }) {
    final mergedHeaders = _mergeHeaders(headers: headers, body: body);
    return (
      handle: _auth._nativeInstance.handle,
      method: method.name,
      path: _qualifyPath(_auth.config.basePath, path),
      query: _stringifyMap(query),
      headers: mergedHeaders,
      body: _encodeBody(body),
    );
  }

  Map<String, String> _mergeHeaders({
    required Map<String, String> headers,
    required Object? body,
  }) {
    final merged = <String, String>{
      if (_defaultOrigin(_auth.config.baseUrl) case final origin?)
        if (!_containsHeader(_headers, 'origin') &&
            !_containsHeader(headers, 'origin'))
          'origin': origin,
      ..._headers,
      ...headers,
    };

    if (body != null &&
        body is! String &&
        body is! Uint8List &&
        !_containsHeader(merged, 'content-type')) {
      merged['content-type'] = 'application/json';
    }

    return merged;
  }

  @override
  String toString() {
    return 'DartEdgeAuthApi(basePath: ${_auth.config.basePath}, '
        'headers: ${_headers.length})';
  }
}

/// Admin-only Better Auth routes scoped to one [DartEdgeAuthApi] context.
final class DartEdgeAuthAdminApi {
  const DartEdgeAuthAdminApi._(this._api);

  final DartEdgeAuthApi _api;

  Map<String, String> get headers => _api.headers;

  DartEdgeAuthAdminApi withHeader(String name, String value) {
    return DartEdgeAuthAdminApi._(_api.withHeader(name, value));
  }

  DartEdgeAuthAdminApi withHeaders(Map<String, String> headers) {
    return DartEdgeAuthAdminApi._(_api.withHeaders(headers));
  }

  DartEdgeAuthAdminApi withBearerToken(String token) {
    return DartEdgeAuthAdminApi._(_api.withBearerToken(token));
  }

  DartEdgeAuthAdminApi withSessionToken(String token) {
    return DartEdgeAuthAdminApi._(_api.withSessionToken(token));
  }

  DartEdgeAuthAdminApi withOrigin(String origin) {
    return DartEdgeAuthAdminApi._(_api.withOrigin(origin));
  }

  DartEdgeAuthAdminApi withUserAgent(String userAgent) {
    return DartEdgeAuthAdminApi._(_api.withUserAgent(userAgent));
  }

  DartEdgeAuthAdminApi withForwardedFor(String ipAddress) {
    return DartEdgeAuthAdminApi._(_api.withForwardedFor(ipAddress));
  }

  Future<DartEdgeAuthApiResponse> setRole({
    required String userId,
    required String role,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_set_role',
      body: {'userId': userId, 'role': role},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> createUser({
    required String email,
    required String password,
    required String name,
    String? role,
    Object? data,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_create_user',
      body: {
        'email': email,
        'password': password,
        'name': name,
        if (role case final role?) 'role': role,
        if (data case final data?) 'data': data,
      },
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> listUsers({
    int? limit,
    int? offset,
    String? searchField,
    Object? searchValue,
    String? searchOperator,
    String? sortBy,
    String? sortDirection,
    String? filterField,
    Object? filterValue,
    String? filterOperator,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_list_users',
      query: {
        if (limit case final limit?) 'limit': limit,
        if (offset case final offset?) 'offset': offset,
        if (searchField case final searchField?) 'searchField': searchField,
        if (searchValue case final searchValue?) 'searchValue': searchValue,
        if (searchOperator case final searchOperator?)
          'searchOperator': searchOperator,
        if (sortBy case final sortBy?) 'sortBy': sortBy,
        if (sortDirection case final sortDirection?)
          'sortDirection': sortDirection,
        if (filterField case final filterField?) 'filterField': filterField,
        if (filterValue case final filterValue?) 'filterValue': filterValue,
        if (filterOperator case final filterOperator?)
          'filterOperator': filterOperator,
      },
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> listUserSessions({
    required String userId,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_list_user_sessions',
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> banUser({
    required String userId,
    String? banReason,
    int? banExpiresIn,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_ban_user',
      body: {
        'userId': userId,
        if (banReason case final banReason?) 'banReason': banReason,
        if (banExpiresIn case final banExpiresIn?) 'banExpiresIn': banExpiresIn,
      },
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> unbanUser({required String userId}) async {
    return (await _api.callOperation(
      operationId: 'admin_unban_user',
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> impersonateUser({
    required String userId,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_impersonate_user',
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> stopImpersonating() async {
    return (await _api.callOperation(
      operationId: 'admin_stop_impersonating',
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> revokeUserSession({
    required String sessionToken,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_revoke_user_session',
      body: {'sessionToken': sessionToken},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> revokeUserSessions({
    required String userId,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_revoke_user_sessions',
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> removeUser({required String userId}) async {
    return (await _api.callOperation(
      operationId: 'admin_remove_user',
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> setUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_set_user_password',
      body: {'userId': userId, 'newPassword': newPassword},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> hasPermission({
    Object? permission,
    Object? permissions,
  }) async {
    return (await _api.callOperation(
      operationId: 'admin_has_permission',
      body: {
        if (permission case final permission?) 'permission': permission,
        if (permissions case final permissions?) 'permissions': permissions,
      },
    )).requireSuccess();
  }

  @override
  String toString() {
    return 'DartEdgeAuthAdminApi(headers: ${headers.length})';
  }
}

/// One direct Better Auth backend response.
final class DartEdgeAuthApiResponse {
  DartEdgeAuthApiResponse({
    required this.status,
    required this.contentType,
    required this.headers,
    required this.body,
  });

  final int status;
  final String contentType;
  final List<HttpHeader> headers;
  final String body;

  late final Object? jsonBody = _decodeJsonBody();

  bool get isSuccess => status >= 200 && status < 300;

  DartEdgeAuthApiResponse requireSuccess() {
    if (isSuccess) {
      return this;
    }
    throw DartEdgeAuthApiException(this);
  }

  Map<String, Object?> get jsonObject => switch (jsonBody) {
    final Map<String, Object?> body => body,
    null => throw StateError('Auth response body is empty.'),
    _ => throw StateError('Auth response body is not a JSON object.'),
  };

  List<Object?> get jsonList => switch (jsonBody) {
    final List<Object?> body => body,
    null => throw StateError('Auth response body is empty.'),
    _ => throw StateError('Auth response body is not a JSON array.'),
  };

  String? header(String name) {
    for (final entry in headers) {
      if (entry.name.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  Object? _decodeJsonBody() {
    if (body.isEmpty) {
      return null;
    }
    if (!_looksLikeJson(contentType: contentType, body: body)) {
      return null;
    }
    return jsonDecode(body);
  }

  @override
  String toString() {
    return 'DartEdgeAuthApiResponse(status: $status, '
        'contentType: $contentType, headers: ${headers.length})';
  }
}

/// Thrown when a direct Better Auth backend call returns a non-success status.
final class DartEdgeAuthApiException implements Exception {
  const DartEdgeAuthApiException(this.response);

  final DartEdgeAuthApiResponse response;

  int get status => response.status;

  String get message {
    final jsonBody = response.jsonBody;
    if (jsonBody case {'message': final String message}) {
      return message;
    }
    if (response.body.isNotEmpty) {
      return response.body;
    }
    return 'Better Auth call failed with status $status.';
  }

  @override
  String toString() {
    return 'DartEdgeAuthApiException(status: $status, message: $message)';
  }
}

_AsyncAuthResponse _performNativeAuthRequest(_AsyncAuthRequest request) {
  final response = DartEdgeAuthNative.handleRequest(
    request.handle,
    method: _httpMethodFromName(request.method),
    path: request.path,
    query: request.query,
    headers: request.headers,
    body: request.body,
  );

  return (
    status: response.status,
    contentType: response.contentType,
    headers: [
      for (final header in response.headers)
        (name: header.name, value: header.value),
    ],
    body: response.body,
  );
}

DartEdgeAuthApiResponse _responseFromAsync(_AsyncAuthResponse response) {
  return DartEdgeAuthApiResponse(
    status: response.status,
    contentType: response.contentType,
    headers: [
      for (final header in response.headers)
        HttpHeader(header.name, header.value),
    ],
    body: response.body,
  );
}

HttpMethod _httpMethodFromName(String method) => switch (method) {
  'get' => HttpMethod.get,
  'post' => HttpMethod.post,
  'put' => HttpMethod.put,
  'patch' => HttpMethod.patch,
  'delete' => HttpMethod.delete,
  'head' => HttpMethod.head,
  'options' => HttpMethod.options,
  _ => throw StateError('Unsupported HTTP method name "$method".'),
};

bool _containsHeader(Map<String, String> headers, String name) {
  return headers.keys.any((key) => key.toLowerCase() == name.toLowerCase());
}

String? _defaultOrigin(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  return uri.origin;
}

String _qualifyPath(String basePath, String path) {
  final normalizedPath = switch (path) {
    '' => '/',
    final value when value.startsWith('/') => value,
    final value => '/$value',
  };

  if (basePath == '/' ||
      normalizedPath == basePath ||
      normalizedPath.startsWith('$basePath/')) {
    return normalizedPath;
  }

  return '$basePath$normalizedPath';
}

bool _looksLikeJson({required String contentType, required String body}) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return true;
  }
  return contentType.toLowerCase().contains('json');
}
