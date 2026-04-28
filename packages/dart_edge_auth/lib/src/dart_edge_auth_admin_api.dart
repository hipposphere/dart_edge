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

  Future<DartEdgeAuthUserResult> setRole({
    required String userId,
    required String role,
  }) async {
    return DartEdgeAuthUserResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminSetRole,
        body: {'userId': userId, 'role': role},
      ),
    );
  }

  Future<DartEdgeAuthUserResult> createUser({
    required String email,
    required String password,
    required String name,
    String? role,
    Object? data,
  }) async {
    return DartEdgeAuthUserResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminCreateUser,
        body: {
          'email': email,
          'password': password,
          'name': name,
          if (role case final role?) 'role': role,
          if (data case final data?) 'data': data,
        },
      ),
    );
  }

  Future<DartEdgeAuthListUsersResult> listUsers({
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
    return DartEdgeAuthListUsersResult.fromResponse(
      await _api.callKnownOperation(
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
      ),
    );
  }

  Future<DartEdgeAuthListSessionsResult> listUserSessions({
    required String userId,
  }) async {
    return DartEdgeAuthListSessionsResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminListUserSessions,
        body: {'userId': userId},
      ),
    );
  }

  Future<DartEdgeAuthUserResult> banUser({
    required String userId,
    String? banReason,
    int? banExpiresIn,
  }) async {
    return DartEdgeAuthUserResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminBanUser,
        body: {
          'userId': userId,
          if (banReason case final banReason?) 'banReason': banReason,
          if (banExpiresIn case final banExpiresIn?)
            'banExpiresIn': banExpiresIn,
        },
      ),
    );
  }

  Future<DartEdgeAuthUserResult> unbanUser({required String userId}) async {
    return DartEdgeAuthUserResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminUnbanUser,
        body: {'userId': userId},
      ),
    );
  }

  Future<DartEdgeAuthSessionUserResult> impersonateUser({
    required String userId,
  }) async {
    return DartEdgeAuthSessionUserResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminImpersonateUser,
        body: {'userId': userId},
      ),
    );
  }

  Future<DartEdgeAuthSessionUserResult> stopImpersonating() async {
    return DartEdgeAuthSessionUserResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminStopImpersonating,
      ),
    );
  }

  Future<DartEdgeAuthSuccessResult> revokeUserSession({
    required String sessionToken,
  }) async {
    return DartEdgeAuthSuccessResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminRevokeUserSession,
        body: {'sessionToken': sessionToken},
      ),
    );
  }

  Future<DartEdgeAuthSuccessResult> revokeUserSessions({
    required String userId,
  }) async {
    return DartEdgeAuthSuccessResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminRevokeUserSessions,
        body: {'userId': userId},
      ),
    );
  }

  Future<DartEdgeAuthSuccessResult> removeUser({required String userId}) async {
    return DartEdgeAuthSuccessResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminRemoveUser,
        body: {'userId': userId},
      ),
    );
  }

  Future<DartEdgeAuthStatusResult> setUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    return DartEdgeAuthStatusResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminSetUserPassword,
        body: {'userId': userId, 'newPassword': newPassword},
      ),
    );
  }

  Future<DartEdgeAuthPermissionResult> hasPermission({
    Object? permission,
    Object? permissions,
  }) async {
    return DartEdgeAuthPermissionResult.fromResponse(
      await _api.callKnownOperation(
        operation: DartEdgeAuthOperation.adminHasPermission,
        body: {
          if (permission case final permission?) 'permission': permission,
          if (permissions case final permissions?) 'permissions': permissions,
        },
      ),
    );
  }

  @override
  String toString() {
    return 'DartEdgeAuthAdminApi(headers: ${headers.length})';
  }
}
