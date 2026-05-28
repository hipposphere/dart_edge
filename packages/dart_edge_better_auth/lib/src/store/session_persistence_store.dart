part of '../database.dart';

extension BetterAuthStoreSessionPersistence on BetterAuthStore {
  Future<BetterAuthSession> _createSession(
    SqlExecutor executor,
    String userId, {
    String? impersonatedBy,
    Duration? expiresIn,
  }) async {
    final now = DateTime.now().toUtc();
    final session = BetterAuthSession(
      id: _generateId(),
      expiresAt: now.add(expiresIn ?? options.session.expiresIn),
      token: _generateToken(options.secret),
      createdAt: now,
      updatedAt: now,
      userId: userId,
      impersonatedBy: impersonatedBy,
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
          impersonatedBy: session.impersonatedBy,
        ).toColumns(),
      ),
    );
    return session;
  }
}
