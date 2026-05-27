part of '../database.dart';

extension BetterAuthStoreUserProfile on BetterAuthStore {
  Future<BetterAuthAdminUserResult> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
  }) async {
    if (name == null && email == null && role == null) {
      final existing = await pool.withTransaction(
        (transaction) => _findUserById(transaction, userId),
      );
      if (existing == null) {
        throw const BetterAuthApiException(
          status: 404,
          code: 'USER_NOT_FOUND',
          message: 'User not found',
        );
      }
      return BetterAuthAdminUserResult(user: existing);
    }

    final result = await pool.withTransaction((transaction) async {
      final assignments = <String>[
        '"updatedAt" = ${_placeholder('updatedAt')}',
      ];
      final parameters = <String, Object?>{
        'id': userId,
        'updatedAt': DateTime.now().toUtc(),
      };
      if (name != null) {
        assignments.add('name = ${_placeholder('name')}');
        parameters['name'] = name;
      }
      if (email != null) {
        assignments.add('email = ${_placeholder('email')}');
        parameters['email'] = _normalizeEmail(email);
      }
      if (role != null) {
        assignments.add('role = ${_placeholder('role')}');
        parameters['role'] = role;
      }

      await transaction.execute(
        _statement('''
          UPDATE ${_table('user')}
          SET ${assignments.join(', ')}
          WHERE id = ${_placeholder('id')}
          ''', parameters),
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
