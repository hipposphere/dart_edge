part of 'dart_edge_auth.dart';

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
    return withHeader('cookie', 'better-auth.session_token=$token');
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
    final response = await _auth._workerPool.request(
      _requestForCall(
        method: method,
        path: path,
        query: query,
        headers: headers,
        body: body,
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
    final route = _auth._routeForOperationId(operationId);
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
    final route = _auth._routeForOperationId(operationId);
    return callSync(
      method: route.method,
      path: _resolvePath(route.path, pathParams),
      query: query,
      headers: headers,
      body: body,
    );
  }

  /// Calls one known Better Auth route by compile-time operation token.
  Future<DartEdgeAuthApiResponse> callKnownOperation({
    required DartEdgeAuthOperation operation,
    Map<String, String> pathParams = const <String, String>{},
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) {
    final route = _auth._routeForOperation(operation);
    return call(
      method: route.method,
      path: _resolvePath(route.path, pathParams),
      query: query,
      headers: headers,
      body: body,
    );
  }

  /// Blocking version of [callKnownOperation].
  DartEdgeAuthApiResponse callKnownOperationSync({
    required DartEdgeAuthOperation operation,
    Map<String, String> pathParams = const <String, String>{},
    Map<String, Object?> query = const <String, Object?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) {
    final route = _auth._routeForOperation(operation);
    return callSync(
      method: route.method,
      path: _resolvePath(route.path, pathParams),
      query: query,
      headers: headers,
      body: body,
    );
  }

  Future<DartEdgeAuthSignUpResult> signUpEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    return DartEdgeAuthSignUpResult.fromResponse(
      await callKnownOperation(
        operation: DartEdgeAuthOperation.signUpEmail,
        body: {'email': email, 'password': password, 'name': name},
      ),
    );
  }

  Future<DartEdgeAuthSignInResult> signInEmail({
    required String email,
    required String password,
  }) async {
    return DartEdgeAuthSignInResult.fromResponse(
      await callKnownOperation(
        operation: DartEdgeAuthOperation.signInEmail,
        body: {'email': email, 'password': password},
      ),
    );
  }

  Future<DartEdgeAuthOAuthSignInResult> signInOAuth({
    required String provider,
    required String callbackUrl,
    List<String>? scopes,
  }) async {
    return DartEdgeAuthOAuthSignInResult.fromResponse(
      await callKnownOperation(
        operation: DartEdgeAuthOperation.socialSignIn,
        body: {
          'provider': provider,
          'callbackURL': callbackUrl,
          'scopes': ?scopes,
        },
      ),
    );
  }

  Future<DartEdgeAuthApiResponse> oauthCallback({
    required String provider,
    required String code,
    required String state,
    Map<String, String> headers = const <String, String>{},
  }) {
    return callKnownOperation(
      operation: DartEdgeAuthOperation.oauthCallback,
      pathParams: {'provider': provider},
      query: {'code': code, 'state': state},
      headers: headers,
    );
  }

  Future<DartEdgeAuthSessionResult> getSession({
    bool post = false,
    Map<String, String> headers = const <String, String>{},
  }) async {
    return DartEdgeAuthSessionResult.fromResponse(
      await callKnownOperation(
        operation: post
            ? DartEdgeAuthOperation.getSessionPost
            : DartEdgeAuthOperation.getSession,
        headers: headers,
      ),
    );
  }

  Future<DartEdgeAuthSessionResult?> tryGetSession({
    bool post = false,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final response = await callKnownOperation(
      operation: post
          ? DartEdgeAuthOperation.getSessionPost
          : DartEdgeAuthOperation.getSession,
      headers: headers,
    );
    if (!response.isSuccess) {
      return null;
    }
    return DartEdgeAuthSessionResult.fromResponse(response);
  }

  Future<DartEdgeAuthSuccessResult> signOut() async {
    return DartEdgeAuthSuccessResult.fromResponse(
      await callKnownOperation(operation: DartEdgeAuthOperation.signOut),
    );
  }

  Future<DartEdgeAuthStatusResult> updateUser({
    String? email,
    String? name,
    String? image,
    String? username,
    String? displayUsername,
    String? role,
    Object? metadata,
  }) async {
    return DartEdgeAuthStatusResult.fromResponse(
      await callKnownOperation(
        operation: DartEdgeAuthOperation.updateUser,
        body: {
          'email': ?email,
          'name': ?name,
          'image': ?image,
          'username': ?username,
          'displayUsername': ?displayUsername,
          'role': ?role,
          'metadata': ?metadata,
        },
      ),
    );
  }

  Future<DartEdgeAuthStatusResult> changeEmail({
    required String newEmail,
  }) async {
    return DartEdgeAuthStatusResult.fromResponse(
      await callKnownOperation(
        operation: DartEdgeAuthOperation.changeEmail,
        body: {'newEmail': newEmail},
      ),
    );
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
