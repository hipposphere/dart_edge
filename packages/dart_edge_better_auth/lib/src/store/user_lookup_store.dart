part of '../database.dart';

extension BetterAuthStoreUserLookup on BetterAuthStore {
  Future<BetterAuthUser?> _findUserByEmail(
    SqlExecutor executor,
    String email,
  ) async {
    final result = await executor.execute(
      _statement(
        'SELECT * FROM ${_table('user')} WHERE email = ${_placeholder('email')} LIMIT 1',
        {'email': email},
      ),
    );
    final row = result.rows.singleOrNull;
    return row == null ? null : _userFromRow(row);
  }

  Future<BetterAuthUser?> _findUserById(SqlExecutor executor, String id) async {
    final result = await executor.execute(
      _statement(
        'SELECT * FROM ${_table('user')} WHERE id = ${_placeholder('id')} LIMIT 1',
        {'id': id},
      ),
    );
    final row = result.rows.singleOrNull;
    return row == null ? null : _userFromRow(row);
  }
}
