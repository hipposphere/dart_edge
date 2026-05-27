part of '../database.dart';

extension BetterAuthStoreUserCreation on BetterAuthStore {
  Future<BetterAuthAuthResult> createUser({
    required String email,
    required String password,
    required String name,
    String? role,
    bool createSession = false,
  }) async {
    _validatePassword(password);
    final hasher = options.emailAndPassword.hash ?? betterAuthHashPassword;
    final passwordHash = await hasher(password);
    return pool.withTransaction((transaction) async {
      final now = DateTime.now().toUtc();
      final normalizedEmail = _normalizeEmail(email);
      final existing = await _findUserByEmail(transaction, normalizedEmail);
      if (existing != null) {
        throw const BetterAuthApiException(
          status: 409,
          code: 'USER_ALREADY_EXISTS',
          message: 'User already exists',
        );
      }

      final userId = _generateId();
      final user = BetterAuthUser(
        id: userId,
        name: name,
        email: normalizedEmail,
        emailVerified: false,
        createdAt: now,
        updatedAt: now,
        role: role,
      );
      await transaction.execute(
        _insertStatement(
          _schema.user,
          BetterAuthUserInsert(
            id: SqlValue(user.id),
            name: user.name,
            email: user.email,
            emailVerified: user.emailVerified,
            image: user.image,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
            role: user.role,
            banned: null,
            banReason: null,
            banExpires: null,
            phoneNumber: null,
            phoneNumberVerified: null,
          ).toColumns(),
        ),
      );
      await transaction.execute(
        _insertStatement(
          _schema.account,
          BetterAuthAccountInsert(
            id: SqlValue(_generateId()),
            accountId: user.id,
            providerId: 'credential',
            userId: user.id,
            accessToken: null,
            refreshToken: null,
            idToken: null,
            accessTokenExpiresAt: null,
            refreshTokenExpiresAt: null,
            scope: null,
            password: passwordHash,
            createdAt: now,
            updatedAt: now,
          ).toColumns(),
        ),
      );

      final session = createSession
          ? await _createSession(transaction, user.id)
          : BetterAuthSession(
              id: '',
              expiresAt: now,
              token: '',
              createdAt: now,
              updatedAt: now,
              userId: user.id,
            );
      return BetterAuthAuthResult(user: user, session: session);
    });
  }

  Future<BetterAuthAdminUserResult> createAdminUser({
    required String email,
    required String password,
    required String name,
    String? role,
  }) async {
    final result = await createUser(
      email: email,
      password: password,
      name: name,
      role: role ?? options.admin.defaultAdminRole,
    );
    return BetterAuthAdminUserResult(user: result.user);
  }
}
