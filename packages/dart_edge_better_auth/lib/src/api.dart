import 'database.dart';
import 'error.dart';
import 'models.dart';

part 'api/admin_api.dart';

final class BetterAuthApi {
  BetterAuthApi(this._store, {String? bearerToken})
    : _bearerToken = bearerToken,
      admin = BetterAuthAdminApi(_store, bearerToken: bearerToken);

  final BetterAuthStore _store;
  final BetterAuthAdminApi admin;
  final String? _bearerToken;

  BetterAuthApi withBearerToken(String token) {
    return BetterAuthApi(_store, bearerToken: token);
  }

  Future<BetterAuthAuthResult> signUpEmail({
    required String email,
    required String password,
    required String name,
  }) {
    return _store.gateways.credentials.signUpEmail(
      email: email,
      password: password,
      name: name,
    );
  }

  Future<BetterAuthAuthResult> signInEmail({
    required String email,
    required String password,
  }) {
    return _store.gateways.credentials.signInEmail(
      email: email,
      password: password,
    );
  }

  Future<BetterAuthSessionResult> getSession({String? token}) async {
    final session = await tryGetSession(token: token);
    if (session == null) {
      throw StateError('No active Better Auth session.');
    }
    return session;
  }

  Future<BetterAuthSessionResult?> tryGetSession({String? token}) {
    final effectiveToken = token ?? _bearerToken;
    if (effectiveToken == null) {
      return Future.value();
    }
    return _store.gateways.sessions.getSession(effectiveToken);
  }

  Future<BetterAuthSuccessResult> signOut({String? token}) {
    final effectiveToken = token ?? _bearerToken;
    if (effectiveToken == null) {
      return Future.value(const BetterAuthSuccessResult(success: true));
    }
    return _store.gateways.sessions.signOut(effectiveToken);
  }
}
