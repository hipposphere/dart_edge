import '../database.dart';
import '../models.dart';

final class BetterAuthAdminGateway {
  BetterAuthAdminGateway(this._store);

  final BetterAuthStore _store;

  Future<BetterAuthAdminUserResult> createUser({
    required String token,
    required String email,
    required String password,
    required String name,
    String? role,
  }) {
    return _store.adminCreateUser(
      token: token,
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }

  Future<BetterAuthAdminUserResult> setRole({
    required String token,
    required String userId,
    required String role,
  }) {
    return _store.adminSetRole(token: token, userId: userId, role: role);
  }

  Future<BetterAuthAdminUserResult> getUser({
    required String token,
    required String userId,
  }) {
    return _store.adminGetUser(token: token, userId: userId);
  }

  Future<BetterAuthListUsersResult> listUsers({
    required String token,
    int limit = 100,
  }) {
    return _store.adminListUsers(token: token, limit: limit);
  }

  Future<BetterAuthListUserSessionsResult> listUserSessions({
    required String token,
    required String userId,
  }) {
    return _store.adminListUserSessions(token: token, userId: userId);
  }

  Future<BetterAuthPermissionResult> hasPermission({
    String? token,
    String? userId,
    String? role,
    required Map<String, List<String>> permissions,
  }) {
    return _store.adminHasPermission(
      token: token,
      userId: userId,
      role: role,
      permissions: permissions,
    );
  }

  Future<BetterAuthAdminUserResult> updateUser({
    required String token,
    required String userId,
    String? name,
    String? email,
    String? role,
  }) {
    return _store.adminUpdateUser(
      token: token,
      userId: userId,
      name: name,
      email: email,
      role: role,
    );
  }

  Future<BetterAuthAdminUserResult> banUser({
    required String token,
    required String userId,
    String? banReason,
    DateTime? banExpires,
  }) {
    return _store.adminBanUser(
      token: token,
      userId: userId,
      banReason: banReason,
      banExpires: banExpires,
    );
  }

  Future<BetterAuthAdminUserResult> unbanUser({
    required String token,
    required String userId,
  }) {
    return _store.adminUnbanUser(token: token, userId: userId);
  }

  Future<BetterAuthSuccessResult> removeUser({
    required String token,
    required String userId,
  }) {
    return _store.adminRemoveUser(token: token, userId: userId);
  }

  Future<BetterAuthSuccessResult> setUserPassword({
    required String token,
    required String userId,
    required String password,
  }) {
    return _store.adminSetUserPassword(
      token: token,
      userId: userId,
      password: password,
    );
  }

  Future<BetterAuthSuccessResult> revokeUserSession({
    required String token,
    required String sessionToken,
  }) {
    return _store.adminRevokeUserSession(
      token: token,
      sessionToken: sessionToken,
    );
  }

  Future<BetterAuthSuccessResult> revokeUserSessions({
    required String token,
    required String userId,
  }) {
    return _store.adminRevokeUserSessions(token: token, userId: userId);
  }

  Future<BetterAuthSessionResult> impersonateUser({
    required String token,
    required String userId,
  }) {
    return _store.adminImpersonateUser(token: token, userId: userId);
  }

  Future<BetterAuthSessionResult> stopImpersonating({
    required String token,
    required String adminSessionToken,
  }) {
    return _store.adminStopImpersonating(
      token: token,
      adminSessionToken: adminSessionToken,
    );
  }
}
