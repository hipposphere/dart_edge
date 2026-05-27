import 'database.dart';
import 'models.dart';

final class BetterAuthTrustedApi {
  BetterAuthTrustedApi(BetterAuthStore store)
    : admin = BetterAuthTrustedAdminApi(store),
      _store = store;

  final BetterAuthStore _store;
  final BetterAuthTrustedAdminApi admin;

  Future<BetterAuthAdminUserResult> createUser({
    required String email,
    required String password,
    required String name,
    String? role,
  }) {
    return _store.gateways.users.createAdminUser(
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }

  Future<BetterAuthSessionResult?> getSession(String token) {
    return _store.gateways.sessions.getSession(token);
  }

  Future<BetterAuthListUsersResult> listUsers({int limit = 100}) {
    return _store.gateways.users.listUsers(limit: limit);
  }
}

final class BetterAuthTrustedAdminApi {
  BetterAuthTrustedAdminApi(this._store);

  final BetterAuthStore _store;

  Future<BetterAuthAdminUserResult> createUser({
    required String email,
    required String password,
    required String name,
    String? role,
  }) {
    return _store.gateways.users.createAdminUser(
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }

  Future<BetterAuthAdminUserResult> setRole({
    required String userId,
    required String role,
  }) {
    return _store.gateways.users.setRole(userId: userId, role: role);
  }

  Future<BetterAuthListUsersResult> listUsers({int limit = 100}) {
    return _store.gateways.users.listUsers(limit: limit);
  }

  Future<void> revokeUserSessions(String userId) {
    return _store.gateways.sessions.revokeUserSessions(userId);
  }

  Future<BetterAuthAdminUserResult> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
  }) {
    return _store.gateways.users.updateUser(
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
  }) {
    return _store.gateways.users.banUser(
      userId: userId,
      banReason: banReason,
      banExpires: banExpires,
    );
  }

  Future<BetterAuthAdminUserResult> unbanUser(String userId) {
    return _store.gateways.users.unbanUser(userId);
  }

  Future<void> removeUser(String userId) {
    return _store.gateways.users.removeUser(userId);
  }

  Future<void> setUserPassword({
    required String userId,
    required String password,
  }) {
    return _store.gateways.users.setUserPassword(
      userId: userId,
      password: password,
    );
  }

  Future<void> revokeSession(String sessionToken) {
    return _store.gateways.sessions.revokeSession(sessionToken);
  }
}
