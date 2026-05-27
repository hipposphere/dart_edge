part of '../database.dart';

extension BetterAuthStoreCredentials on BetterAuthStore {
  Future<BetterAuthAuthResult> signUpEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    _ensureEmailPasswordEnabled();
    _validatePassword(password);
    return createUser(
      email: email,
      password: password,
      name: name,
      role: options.admin.defaultRole,
      createSession: true,
    );
  }

  Future<BetterAuthAuthResult> signInEmail({
    required String email,
    required String password,
  }) async {
    _ensureEmailPasswordEnabled();
    return pool.withTransaction((transaction) async {
      final user = await _findUserByEmail(transaction, _normalizeEmail(email));
      if (user == null) {
        throw const BetterAuthApiException(
          status: 401,
          code: 'INVALID_EMAIL_OR_PASSWORD',
          message: 'Invalid email or password',
        );
      }

      final account = await transaction.execute(
        _statement(
          '''
          SELECT password
          FROM ${_table('account')}
          WHERE "userId" = ${_placeholder('userId')}
            AND "providerId" = ${_placeholder('providerId')}
          LIMIT 1
          ''',
          {'userId': user.id, 'providerId': 'credential'},
        ),
      );
      final hash = account.rows.singleOrNull?['password'] as String?;
      final verify =
          options.emailAndPassword.verify ?? betterAuthVerifyPassword;
      if (hash == null || !await verify(password: password, hash: hash)) {
        throw const BetterAuthApiException(
          status: 401,
          code: 'INVALID_EMAIL_OR_PASSWORD',
          message: 'Invalid email or password',
        );
      }

      final session = await _createSession(transaction, user.id);
      return BetterAuthAuthResult(user: user, session: session);
    });
  }
}
