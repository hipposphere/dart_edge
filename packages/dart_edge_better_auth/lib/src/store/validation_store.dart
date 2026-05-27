part of '../database.dart';

extension BetterAuthStoreValidation on BetterAuthStore {
  void _ensureEmailPasswordEnabled() {
    if (!options.emailAndPassword.enabled) {
      throw const BetterAuthApiException(
        status: 400,
        code: 'EMAIL_AND_PASSWORD_DISABLED',
        message: 'Email and password authentication is disabled',
      );
    }
  }

  void _validatePassword(String password) {
    if (password.length < options.emailAndPassword.minPasswordLength ||
        password.length > options.emailAndPassword.maxPasswordLength) {
      throw BetterAuthApiException(
        status: 400,
        code: 'INVALID_PASSWORD',
        message:
            'Password must be between '
            '${options.emailAndPassword.minPasswordLength} and '
            '${options.emailAndPassword.maxPasswordLength} characters',
      );
    }
  }
}
