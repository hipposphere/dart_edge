import '../database.dart';
import '../models.dart';

final class BetterAuthCredentialGateway {
  BetterAuthCredentialGateway(this._store);

  final BetterAuthStore _store;

  Future<BetterAuthAuthResult> signUpEmail({
    required String email,
    required String password,
    required String name,
  }) {
    return _store.signUpEmail(email: email, password: password, name: name);
  }

  Future<BetterAuthAuthResult> signInEmail({
    required String email,
    required String password,
  }) {
    return _store.signInEmail(email: email, password: password);
  }
}
