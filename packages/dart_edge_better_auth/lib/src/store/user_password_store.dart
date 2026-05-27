part of '../database.dart';

extension BetterAuthStoreUserPassword on BetterAuthStore {
  Future<void> setUserPassword({
    required String userId,
    required String password,
  }) async {
    _validatePassword(password);
    final hasher = options.emailAndPassword.hash ?? betterAuthHashPassword;
    final passwordHash = await hasher(password);
    await pool.withTransaction((transaction) async {
      final account = await transaction.execute(
        _statement(
          '''
          SELECT id FROM ${_table('account')}
          WHERE "userId" = ${_placeholder('userId')}
            AND "providerId" = ${_placeholder('providerId')}
          LIMIT 1
          ''',
          {'userId': userId, 'providerId': 'credential'},
        ),
      );
      final now = DateTime.now().toUtc();
      if (account.rows.isEmpty) {
        await transaction.execute(
          _statement(
            '''
            INSERT INTO ${_table('account')}
              (id, "accountId", "providerId", "userId", password, "createdAt", "updatedAt")
            VALUES (
              ${_placeholder('id')},
              ${_placeholder('accountId')},
              ${_placeholder('providerId')},
              ${_placeholder('userId')},
              ${_placeholder('password')},
              ${_placeholder('createdAt')},
              ${_placeholder('updatedAt')}
            )
            ''',
            {
              'id': _generateId(),
              'accountId': userId,
              'providerId': 'credential',
              'userId': userId,
              'password': passwordHash,
              'createdAt': now,
              'updatedAt': now,
            },
          ),
        );
        return;
      }
      await transaction.execute(
        _statement(
          '''
          UPDATE ${_table('account')}
          SET password = ${_placeholder('password')}, "updatedAt" = ${_placeholder('updatedAt')}
          WHERE "userId" = ${_placeholder('userId')}
            AND "providerId" = ${_placeholder('providerId')}
          ''',
          {
            'userId': userId,
            'providerId': 'credential',
            'password': passwordHash,
            'updatedAt': now,
          },
        ),
      );
    });
  }
}
