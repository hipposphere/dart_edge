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
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminSetRole,
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
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminCreateUser,
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
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminListUsers,
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
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminListUserSessions,
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> banUser({
    required String userId,
    String? banReason,
    int? banExpiresIn,
  }) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminBanUser,
      body: {
        'userId': userId,
        if (banReason case final banReason?) 'banReason': banReason,
        if (banExpiresIn case final banExpiresIn?) 'banExpiresIn': banExpiresIn,
      },
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> unbanUser({required String userId}) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminUnbanUser,
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> impersonateUser({
    required String userId,
  }) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminImpersonateUser,
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> stopImpersonating() async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminStopImpersonating,
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> revokeUserSession({
    required String sessionToken,
  }) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminRevokeUserSession,
      body: {'sessionToken': sessionToken},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> revokeUserSessions({
    required String userId,
  }) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminRevokeUserSessions,
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> removeUser({required String userId}) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminRemoveUser,
      body: {'userId': userId},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> setUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminSetUserPassword,
      body: {'userId': userId, 'newPassword': newPassword},
    )).requireSuccess();
  }

  Future<DartEdgeAuthApiResponse> hasPermission({
    Object? permission,
    Object? permissions,
  }) async {
    return (await _api.callKnownOperation(
      operation: DartEdgeAuthOperation.adminHasPermission,
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
