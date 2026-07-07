part of '../database.dart';

extension BetterAuthStoreUserListing on BetterAuthStore {
  Future<void> removeUser(String userId) async {
    await pool.execute(
      _statement(
        'DELETE FROM ${_table('user')} WHERE id = ${_placeholder('id')}',
        {'id': userId},
      ),
    );
  }

  Future<BetterAuthListUsersResult> listUsers({int limit = 100}) async {
    if (pool.dialect == SqlDialect.postgres) {
      final users = await pool.typed
          .from(_schema.user)
          .selectAll()
          .orderByColumn(_schema.user.createdAt)
          .limit(limit)
          .execute();
      return BetterAuthListUsersResult(
        users: users.map(_userFromGeneratedRow).toList(),
        total: users.length,
      );
    }
    final result = await pool.execute(
      _statement(
        '''
        SELECT *
        FROM ${_table('user')}
        ORDER BY "createdAt" ASC
        LIMIT ${_placeholder('limit')}
        ''',
        {'limit': limit},
      ),
    );
    final users = result.rows.map(_userFromRow).toList();
    return BetterAuthListUsersResult(users: users, total: users.length);
  }
}
