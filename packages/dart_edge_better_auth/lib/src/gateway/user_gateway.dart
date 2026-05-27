import '../database.dart';
import '../models.dart';

final class BetterAuthUserGateway {
  BetterAuthUserGateway(this._store);

  final BetterAuthStore _store;

  Future<BetterAuthAuthResult> createUser({
    required String email,
    required String password,
    required String name,
    String? role,
    bool createSession = false,
  }) {
    return _store.createUser(
      email: email,
      password: password,
      name: name,
      role: role,
      createSession: createSession,
    );
  }

  Future<BetterAuthAdminUserResult> createAdminUser({
    required String email,
    required String password,
    required String name,
    String? role,
  }) {
    return _store.createAdminUser(
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
    return _store.setRole(userId: userId, role: role);
  }

  Future<BetterAuthAdminUserResult> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
  }) {
    return _store.updateUser(
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
    return _store.banUser(
      userId: userId,
      banReason: banReason,
      banExpires: banExpires,
    );
  }

  Future<BetterAuthAdminUserResult> unbanUser(String userId) {
    return _store.unbanUser(userId: userId);
  }

  Future<void> removeUser(String userId) {
    return _store.removeUser(userId);
  }

  Future<void> setUserPassword({
    required String userId,
    required String password,
  }) {
    return _store.setUserPassword(userId: userId, password: password);
  }

  Future<BetterAuthListUsersResult> listUsers({int limit = 100}) {
    return _store.listUsers(limit: limit);
  }
}
