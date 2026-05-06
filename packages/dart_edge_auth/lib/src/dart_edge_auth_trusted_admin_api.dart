part of 'dart_edge_auth.dart';

/// Trusted server-side user administration API.
///
/// This API bypasses request/session authorization and must only be called from
/// backend code that is already trusted by the application.
final class DartEdgeAuthTrustedAdminApi {
  const DartEdgeAuthTrustedAdminApi._(this._auth);

  final DartEdgeAuth _auth;

  Future<DartEdgeAuthUserResult> setRole({
    required String userId,
    required String role,
  }) async {
    return DartEdgeAuthUserResult.fromResponse(
      await _call('setRole', body: {'userId': userId, 'role': role}),
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
      await _call(
        'createUser',
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
      await _call(
        'listUsers',
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
      await _call('listUserSessions', body: {'userId': userId}),
    );
  }

  Future<DartEdgeAuthUserResult> banUser({
    required String userId,
    String? banReason,
    int? banExpiresIn,
  }) async {
    return DartEdgeAuthUserResult.fromResponse(
      await _call(
        'banUser',
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
      await _call('unbanUser', body: {'userId': userId}),
    );
  }

  Future<DartEdgeAuthSessionUserResult> impersonateUser({
    required String userId,
    required String impersonatedByUserId,
    String? ipAddress,
    String? userAgent,
  }) async {
    return DartEdgeAuthSessionUserResult.fromResponse(
      await _call(
        'impersonateUser',
        body: {
          'userId': userId,
          'impersonatedByUserId': impersonatedByUserId,
          if (ipAddress case final ipAddress?) 'ipAddress': ipAddress,
          if (userAgent case final userAgent?) 'userAgent': userAgent,
        },
      ),
    );
  }

  Future<DartEdgeAuthSessionUserResult> stopImpersonating({
    required String sessionToken,
    String? ipAddress,
    String? userAgent,
  }) async {
    return DartEdgeAuthSessionUserResult.fromResponse(
      await _call(
        'stopImpersonating',
        body: {
          'sessionToken': sessionToken,
          if (ipAddress case final ipAddress?) 'ipAddress': ipAddress,
          if (userAgent case final userAgent?) 'userAgent': userAgent,
        },
      ),
    );
  }

  Future<DartEdgeAuthSuccessResult> revokeUserSession({
    required String sessionToken,
  }) async {
    return DartEdgeAuthSuccessResult.fromResponse(
      await _call('revokeUserSession', body: {'sessionToken': sessionToken}),
    );
  }

  Future<DartEdgeAuthSuccessResult> revokeUserSessions({
    required String userId,
  }) async {
    return DartEdgeAuthSuccessResult.fromResponse(
      await _call('revokeUserSessions', body: {'userId': userId}),
    );
  }

  Future<DartEdgeAuthSuccessResult> removeUser({required String userId}) async {
    return DartEdgeAuthSuccessResult.fromResponse(
      await _call('removeUser', body: {'userId': userId}),
    );
  }

  Future<DartEdgeAuthStatusResult> setUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    return DartEdgeAuthStatusResult.fromResponse(
      await _call(
        'setUserPassword',
        body: {'userId': userId, 'newPassword': newPassword},
      ),
    );
  }

  Future<DartEdgeAuthPermissionResult> hasPermission({
    required String userId,
    Object? permission,
    Object? permissions,
  }) async {
    return DartEdgeAuthPermissionResult.fromResponse(
      await _call(
        'hasPermission',
        body: {
          'userId': userId,
          if (permission case final permission?) 'permission': permission,
          if (permissions case final permissions?) 'permissions': permissions,
        },
      ),
    );
  }

  Future<DartEdgeAuthApiResponse> _call(
    String operation, {
    Map<String, Object?> query = const <String, Object?>{},
    Object? body,
  }) async {
    _auth._ensureActive();
    final response = await Isolate.run(
      () => _performNativeTrustedAdminCall((
        handle: _auth._nativeInstance.handle,
        operation: operation,
        query: query,
        body: body,
      )),
    );
    return _responseFromAsync(response);
  }

  @override
  String toString() => 'DartEdgeAuthTrustedAdminApi()';
}
