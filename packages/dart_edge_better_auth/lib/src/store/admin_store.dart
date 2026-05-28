part of '../database.dart';

extension BetterAuthStoreAdmin on BetterAuthStore {
  Future<BetterAuthAdminUserResult> adminCreateUser({
    required String token,
    required String email,
    required String password,
    required String name,
    String? role,
  }) async {
    await _requireAdminSession(token);
    return createAdminUser(
      email: email,
      password: password,
      name: name,
      role: role ?? options.admin.defaultRole,
    );
  }

  Future<BetterAuthAdminUserResult> adminSetRole({
    required String token,
    required String userId,
    required String role,
  }) async {
    await _requireAdminSession(token);
    return setRole(userId: userId, role: role);
  }

  Future<BetterAuthListUsersResult> adminListUsers({
    required String token,
    int limit = 100,
  }) async {
    await _requireAdminSession(token);
    return listUsers(limit: limit);
  }

  Future<BetterAuthAdminUserResult> adminUpdateUser({
    required String token,
    required String userId,
    String? name,
    String? email,
    String? role,
  }) async {
    await _requireAdminSession(token);
    return updateUser(userId: userId, name: name, email: email, role: role);
  }

  Future<BetterAuthAdminUserResult> adminBanUser({
    required String token,
    required String userId,
    String? banReason,
    DateTime? banExpires,
  }) async {
    await _requireAdminSession(token);
    return banUser(
      userId: userId,
      banReason: banReason,
      banExpires: banExpires,
    );
  }

  Future<BetterAuthAdminUserResult> adminUnbanUser({
    required String token,
    required String userId,
  }) async {
    await _requireAdminSession(token);
    return unbanUser(userId: userId);
  }

  Future<BetterAuthSuccessResult> adminRemoveUser({
    required String token,
    required String userId,
  }) async {
    await _requireAdminSession(token);
    await removeUser(userId);
    return const BetterAuthSuccessResult(success: true);
  }

  Future<BetterAuthSuccessResult> adminSetUserPassword({
    required String token,
    required String userId,
    required String password,
  }) async {
    await _requireAdminSession(token);
    await setUserPassword(userId: userId, password: password);
    return const BetterAuthSuccessResult(success: true);
  }

  Future<BetterAuthSuccessResult> adminRevokeUserSession({
    required String token,
    required String sessionToken,
  }) async {
    await _requireAdminSession(token);
    await revokeSession(sessionToken);
    return const BetterAuthSuccessResult(success: true);
  }

  Future<BetterAuthSuccessResult> adminRevokeUserSessions({
    required String token,
    required String userId,
  }) async {
    await _requireAdminSession(token);
    await revokeUserSessions(userId);
    return const BetterAuthSuccessResult(success: true);
  }

  Future<BetterAuthSessionResult> adminImpersonateUser({
    required String token,
    required String userId,
  }) async {
    final adminSession = await _requireAdminSession(token);
    return pool.withTransaction((transaction) async {
      final user = await _findUserById(transaction, userId);
      if (user == null) {
        throw const BetterAuthApiException(
          status: 404,
          code: 'USER_NOT_FOUND',
          message: 'User not found',
        );
      }
      final targetRoles = user.role
          ?.split(',')
          .map((role) => role.trim())
          .where((role) => role.isNotEmpty);
      final targetIsAdmin =
          targetRoles?.contains(options.admin.defaultAdminRole) ?? false;
      if (targetIsAdmin && !options.admin.allowImpersonatingAdmins) {
        throw const BetterAuthApiException(
          status: 403,
          code: 'YOU_CANNOT_IMPERSONATE_ADMINS',
          message: 'You cannot impersonate admins',
        );
      }
      final session = await _createSession(
        transaction,
        user.id,
        impersonatedBy: adminSession.user.id,
        expiresIn: options.admin.impersonationSessionDuration,
      );
      return BetterAuthSessionResult(session: session, user: user);
    });
  }

  Future<BetterAuthSessionResult> _requireAdminSession(String token) async {
    final session = await getSession(token);
    if (session == null) {
      throw const BetterAuthApiException(
        status: 401,
        code: 'UNAUTHORIZED',
        message: 'Unauthorized',
      );
    }
    final roles = session.user.role?.split(',').map((role) => role.trim());
    if (roles == null || !roles.contains(options.admin.defaultAdminRole)) {
      throw const BetterAuthApiException(
        status: 403,
        code: 'FORBIDDEN',
        message: 'You are not allowed to perform this action',
      );
    }
    return session;
  }
}
