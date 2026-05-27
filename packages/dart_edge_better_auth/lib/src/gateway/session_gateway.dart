import '../database.dart';
import '../models.dart';

final class BetterAuthSessionGateway {
  BetterAuthSessionGateway(this._store);

  final BetterAuthStore _store;

  Future<BetterAuthSessionResult?> getSession(String token) {
    return _store.getSession(token);
  }

  Future<BetterAuthSuccessResult> signOut(String token) {
    return _store.signOut(token);
  }

  Future<void> revokeSession(String sessionToken) {
    return _store.revokeSession(sessionToken);
  }

  Future<void> revokeUserSessions(String userId) {
    return _store.revokeUserSessions(userId);
  }
}
