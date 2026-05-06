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
          'role': ?role,
          'data': ?data,
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
          'limit': ?limit,
          'offset': ?offset,
          'searchField': ?searchField,
          'searchValue': ?searchValue,
          'searchOperator': ?searchOperator,
          'sortBy': ?sortBy,
          'sortDirection': ?sortDirection,
          'filterField': ?filterField,
          'filterValue': ?filterValue,
          'filterOperator': ?filterOperator,
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
          'banReason': ?banReason,
          'banExpiresIn': ?banExpiresIn,
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
          'ipAddress': ?ipAddress,
          'userAgent': ?userAgent,
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
          'ipAddress': ?ipAddress,
          'userAgent': ?userAgent,
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
          'permission': ?permission,
          'permissions': ?permissions,
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
