part of '../database.dart';

extension BetterAuthStoreSessions on BetterAuthStore {
  Future<BetterAuthListUserSessionsResult> listUserSessions(
    String userId,
  ) async {
    if (pool.dialect == SqlDialect.postgres) {
      final sessions = await pool.typed
          .from(_schema.session)
          .selectAll()
          .where(_schema.session.userId.equals(userId))
          .orderByColumn(_schema.session.createdAt)
          .execute();
      return BetterAuthListUserSessionsResult(
        sessions: sessions.map(_sessionFromGeneratedRow).toList(),
      );
    }
    final result = await pool.execute(
      _statement(
        '''
        SELECT *
        FROM ${_table('session')}
        WHERE "userId" = ${_placeholder('userId')}
        ORDER BY "createdAt" ASC
        ''',
        {'userId': userId},
      ),
    );
    return BetterAuthListUserSessionsResult(
      sessions: result.rows.map(_sessionFromRow).toList(),
    );
  }

  Future<BetterAuthSessionResult?> getSession(String token) async {
    return pool.withTransaction((transaction) async {
      final result = await transaction.execute(
        _statement(
          '''
          SELECT
            s.id AS session_id,
            s."expiresAt" AS session_expires_at,
            s.token AS session_token,
            s."createdAt" AS session_created_at,
            s."updatedAt" AS session_updated_at,
            s."ipAddress" AS session_ip_address,
            s."userAgent" AS session_user_agent,
            s."userId" AS session_user_id,
            s."impersonatedBy" AS session_impersonated_by,
            u.id AS user_id,
            u.name AS user_name,
            u.email AS user_email,
            u."emailVerified" AS user_email_verified,
            u.image AS user_image,
            u."createdAt" AS user_created_at,
            u."updatedAt" AS user_updated_at,
            u.role AS user_role,
            u.banned AS user_banned,
            u."banReason" AS user_ban_reason,
            u."banExpires" AS user_ban_expires,
            u."phoneNumber" AS user_phone_number,
            u."phoneNumberVerified" AS user_phone_number_verified
          FROM ${_table('session')} s
          INNER JOIN ${_table('user')} u ON u.id = s."userId"
          WHERE s.token = ${_placeholder('token')}
          LIMIT 1
          ''',
          {'token': token},
        ),
      );
      final row = result.rows.singleOrNull;
      if (row == null) {
        return null;
      }
      final session = BetterAuthSession(
        id: row.read<String>('session_id'),
        expiresAt: _readDate(row['session_expires_at']),
        token: row.read<String>('session_token'),
        createdAt: _readDate(row['session_created_at']),
        updatedAt: _readDate(row['session_updated_at']),
        ipAddress: row.readNullable<String>('session_ip_address'),
        userAgent: row.readNullable<String>('session_user_agent'),
        userId: row.read<String>('session_user_id'),
        impersonatedBy: row.readNullable<String>('session_impersonated_by'),
      );
      return BetterAuthSessionResult(
        session: session,
        user: _userFromPrefixedRow(row),
      );
    });
  }

  Future<BetterAuthSuccessResult> signOut(String token) async {
    await pool.execute(
      _statement(
        'DELETE FROM ${_table('session')} WHERE token = ${_placeholder('token')}',
        {'token': token},
      ),
    );
    return const BetterAuthSuccessResult(success: true);
  }

  Future<void> revokeUserSessions(String userId) async {
    await pool.execute(
      _statement(
        'DELETE FROM ${_table('session')} WHERE "userId" = ${_placeholder('userId')}',
        {'userId': userId},
      ),
    );
  }

  Future<void> revokeSession(String sessionToken) async {
    await pool.execute(
      _statement(
        'DELETE FROM ${_table('session')} WHERE token = ${_placeholder('token')}',
        {'token': sessionToken},
      ),
    );
  }
}
