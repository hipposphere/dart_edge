part of 'dart_edge_auth.dart';

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
