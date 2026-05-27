part of '../database.dart';

extension BetterAuthStoreUserBan on BetterAuthStore {
  Future<BetterAuthAdminUserResult> banUser({
    required String userId,
    String? banReason,
    DateTime? banExpires,
  }) async {
    final result = await pool.withTransaction((transaction) async {
      await transaction.execute(
        _statement(
          '''
          UPDATE ${_table('user')}
          SET
            banned = ${_placeholder('banned')},
            "banReason" = ${_placeholder('banReason')},
            "banExpires" = ${_typedPlaceholder('banExpires', 'timestamptz')},
            "updatedAt" = ${_placeholder('updatedAt')}
          WHERE id = ${_placeholder('id')}
          ''',
          {
            'id': userId,
            'banned': true,
            'banReason': banReason,
            'banExpires': banExpires,
            'updatedAt': DateTime.now().toUtc(),
          },
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

  Future<BetterAuthAdminUserResult> unbanUser({required String userId}) async {
    final result = await pool.withTransaction((transaction) async {
      await transaction.execute(
        _statement(
          '''
          UPDATE ${_table('user')}
          SET
            banned = ${_placeholder('banned')},
            "banReason" = ${_placeholder('banReason')},
            "banExpires" = ${_typedPlaceholder('banExpires', 'timestamptz')},
            "updatedAt" = ${_placeholder('updatedAt')}
          WHERE id = ${_placeholder('id')}
          ''',
          {
            'id': userId,
            'banned': false,
            'banReason': null,
            'banExpires': null,
            'updatedAt': DateTime.now().toUtc(),
          },
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
