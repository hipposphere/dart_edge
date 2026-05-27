part of '../database.dart';

extension BetterAuthStoreSessionPersistence on BetterAuthStore {
  Future<BetterAuthSession> _createSession(
    SqlExecutor executor,
    String userId,
  ) async {
    final now = DateTime.now().toUtc();
    final session = BetterAuthSession(
      id: _generateId(),
      expiresAt: now.add(options.session.expiresIn),
      token: _generateToken(options.secret),
      createdAt: now,
      updatedAt: now,
      userId: userId,
    );
    await executor.execute(
      _insertStatement(
        _schema.session,
        BetterAuthSessionInsert(
          id: SqlValue(session.id),
          expiresAt: session.expiresAt,
          token: session.token,
          createdAt: session.createdAt,
          updatedAt: session.updatedAt,
          ipAddress: null,
          userAgent: null,
          userId: session.userId,
          impersonatedBy: null,
        ).toColumns(),
      ),
    );
    return session;
  }
}
