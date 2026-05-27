part of '../api.dart';

final class BetterAuthAdminApi {
  BetterAuthAdminApi(this._store, {this.bearerToken});

  final BetterAuthStore _store;
  final String? bearerToken;

  BetterAuthAdminApi withBearerToken(String token) {
    return BetterAuthAdminApi(_store, bearerToken: token);
  }

  Future<BetterAuthAdminUserResult> createUser({
    required String email,
    required String password,
    required String name,
    String? role,
    String? token,
  }) {
    return _store.gateways.admin.createUser(
      token: _requiredToken(token),
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }

  Future<BetterAuthAdminUserResult> setRole({
    required String userId,
    required String role,
    String? token,
  }) {
    return _store.gateways.admin.setRole(
      token: _requiredToken(token),
      userId: userId,
      role: role,
    );
  }

  Future<BetterAuthListUsersResult> listUsers({
    int limit = 100,
    String? token,
  }) {
    return _store.gateways.admin.listUsers(
      token: _requiredToken(token),
      limit: limit,
    );
  }

  Future<BetterAuthAdminUserResult> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
    String? token,
  }) {
    return _store.gateways.admin.updateUser(
      token: _requiredToken(token),
      userId: userId,
      name: name,
      email: email,
      role: role,
    );
  }

  Future<BetterAuthAdminUserResult> banUser({
    required String userId,
    String? banReason,
    DateTime? banExpires,
    String? token,
  }) {
    return _store.gateways.admin.banUser(
      token: _requiredToken(token),
      userId: userId,
      banReason: banReason,
      banExpires: banExpires,
    );
  }

  Future<BetterAuthAdminUserResult> unbanUser({
    required String userId,
    String? token,
  }) {
    return _store.gateways.admin.unbanUser(
      token: _requiredToken(token),
      userId: userId,
    );
  }

  Future<BetterAuthSuccessResult> removeUser({
    required String userId,
    String? token,
  }) {
    return _store.gateways.admin.removeUser(
      token: _requiredToken(token),
      userId: userId,
    );
  }

  Future<BetterAuthSuccessResult> setUserPassword({
    required String userId,
    required String password,
    String? token,
  }) {
    return _store.gateways.admin.setUserPassword(
      token: _requiredToken(token),
      userId: userId,
      password: password,
    );
  }

  Future<BetterAuthSuccessResult> revokeUserSession({
    required String sessionToken,
    String? token,
  }) {
    return _store.gateways.admin.revokeUserSession(
      token: _requiredToken(token),
      sessionToken: sessionToken,
    );
  }

  Future<BetterAuthSuccessResult> revokeUserSessions({
    required String userId,
    String? token,
  }) {
    return _store.gateways.admin.revokeUserSessions(
      token: _requiredToken(token),
      userId: userId,
    );
  }

  String _requiredToken(String? explicitToken) {
    final token = explicitToken ?? bearerToken;
    if (token == null) {
      throw const BetterAuthApiException(
        status: 401,
        code: 'UNAUTHORIZED',
        message: 'Unauthorized',
      );
    }
    return token;
  }
}
