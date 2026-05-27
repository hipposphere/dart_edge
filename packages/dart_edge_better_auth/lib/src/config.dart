import 'dart:async';

final class BetterAuthOptions {
  const BetterAuthOptions({
    required this.secret,
    required this.baseUrl,
    this.basePath = '/auth',
    this.emailAndPassword = const BetterAuthEmailAndPasswordOptions(),
    this.admin = const BetterAuthAdminOptions(),
    this.database = const BetterAuthDatabaseOptions(),
    this.session = const BetterAuthSessionOptions(),
  });

  final String secret;
  final String baseUrl;
  final String basePath;
  final BetterAuthEmailAndPasswordOptions emailAndPassword;
  final BetterAuthAdminOptions admin;
  final BetterAuthDatabaseOptions database;
  final BetterAuthSessionOptions session;
}

typedef BetterAuthPasswordHasher = FutureOr<String> Function(String password);

typedef BetterAuthPasswordVerifier =
    FutureOr<bool> Function({required String password, required String hash});

final class BetterAuthEmailAndPasswordOptions {
  const BetterAuthEmailAndPasswordOptions({
    this.enabled = true,
    this.minPasswordLength = 8,
    this.maxPasswordLength = 128,
    this.hash,
    this.verify,
  });

  final bool enabled;
  final int minPasswordLength;
  final int maxPasswordLength;
  final BetterAuthPasswordHasher? hash;
  final BetterAuthPasswordVerifier? verify;
}

final class BetterAuthAdminOptions {
  const BetterAuthAdminOptions({
    this.enabled = true,
    this.defaultRole = 'user',
    this.defaultAdminRole = 'admin',
  });

  final bool enabled;
  final String defaultRole;
  final String defaultAdminRole;
}

final class BetterAuthDatabaseOptions {
  const BetterAuthDatabaseOptions({this.postgresSchema});

  final String? postgresSchema;
}

final class BetterAuthSessionOptions {
  const BetterAuthSessionOptions({this.expiresIn = const Duration(days: 7)});

  final Duration expiresIn;
}
