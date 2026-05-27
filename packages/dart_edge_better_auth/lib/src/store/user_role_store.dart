part of '../database.dart';

extension BetterAuthStoreUserRole on BetterAuthStore {
  Future<BetterAuthAdminUserResult> setRole({
    required String userId,
    required String role,
  }) async {
    final result = await pool.withTransaction((transaction) async {
      final now = DateTime.now().toUtc();
      await transaction.execute(
        _statement(
          '''
          UPDATE ${_table('user')}
          SET role = ${_placeholder('role')}, "updatedAt" = ${_placeholder('updatedAt')}
          WHERE id = ${_placeholder('id')}
          ''',
          {'id': userId, 'role': role, 'updatedAt': now},
        ),
      );
      return _findUserById(transaction, userId);
    });
    if (result == null) {
      throw const BetterAuthApiException(
        status: 404,
        code: 'USER_NOT_FOUND',
        message: 'User not found',
      );
    }
    return BetterAuthAdminUserResult(user: result);
  }
}
