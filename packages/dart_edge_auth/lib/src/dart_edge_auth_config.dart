import 'dart_edge_auth_database.dart';

/// Configures the native Better Auth instance used by [DartEdgeAuth].
final class DartEdgeAuthConfig {
  const DartEdgeAuthConfig({
    required this.secret,
    required this.baseUrl,
    this.database = const DartEdgeAuthDatabase.memory(),
    this.basePath = '/auth',
    this.appName = 'Dart Edge',
    this.passwordMinLength = 8,
    this.trustedOrigins = const <String>[],
    this.enableEmailPassword = true,
    this.enableSignup = true,
    this.enableSessionManagement = true,
    this.enablePasswordManagement = true,
    this.enableAccountManagement = true,
    this.enableEmailVerification = false,
    this.enableRateLimit = true,
    this.admin,
  });

  /// Secret used to sign tokens and session state.
  final String secret;

  /// Public base URL where the application is served.
  final String baseUrl;

  /// Database adapter configuration used by the native Better Auth runtime.
  final DartEdgeAuthDatabase database;

  /// URL prefix under which the auth routes are mounted.
  final String basePath;

  /// Display name exposed to the auth experience.
  final String appName;

  /// Minimum password length enforced by the auth backend.
  final int passwordMinLength;

  /// Additional origins trusted by the auth backend.
  final List<String> trustedOrigins;

  /// Enables username/password sign-in flows.
  final bool enableEmailPassword;

  /// Enables self-service user sign-up.
  final bool enableSignup;

  /// Enables session lookup and invalidation endpoints.
  final bool enableSessionManagement;

  /// Enables password reset and change endpoints.
  final bool enablePasswordManagement;

  /// Enables account-management endpoints.
  final bool enableAccountManagement;

  /// Enables email-verification flows.
  final bool enableEmailVerification;

  /// Enables Better Auth's in-memory rate limiting middleware.
  final bool enableRateLimit;

  /// Enables Better Auth's admin plugin when configured.
  final DartEdgeAuthAdminConfig? admin;

  /// Serializes the config into the JSON shape expected by the native layer.
  Map<String, Object?> toJson() => {
    'secret': secret,
    'baseUrl': baseUrl,
    'database': database.toJson(),
    'basePath': _normalizeBasePath(basePath),
    'appName': appName,
    'passwordMinLength': passwordMinLength,
    'trustedOrigins': trustedOrigins,
    'enableEmailPassword': enableEmailPassword,
    'enableSignup': enableSignup,
    'enableSessionManagement': enableSessionManagement,
    'enablePasswordManagement': enablePasswordManagement,
    'enableAccountManagement': enableAccountManagement,
    'enableEmailVerification': enableEmailVerification,
    'enableRateLimit': enableRateLimit,
    'admin': ?admin?.toJson(),
  };
}

/// Configures Better Auth's admin plugin.
final class DartEdgeAuthAdminConfig {
  const DartEdgeAuthAdminConfig({
    this.adminRole = 'admin',
    this.defaultUserRole = 'user',
    this.allowBanAdmin = false,
    this.defaultPageLimit = 100,
    this.maxPageLimit = 500,
  });

  /// Role required to call admin endpoints.
  final String adminRole;

  /// Default role assigned by `admin.createUser(...)`.
  final String defaultUserRole;

  /// Whether one admin may ban another admin.
  final bool allowBanAdmin;

  /// Default user page size for `admin.listUsers(...)`.
  final int defaultPageLimit;

  /// Maximum user page size for `admin.listUsers(...)`.
  final int maxPageLimit;

  Map<String, Object?> toJson() => {
    'adminRole': adminRole,
    'defaultUserRole': defaultUserRole,
    'allowBanAdmin': allowBanAdmin,
    'defaultPageLimit': defaultPageLimit,
    'maxPageLimit': maxPageLimit,
  };
}

String _normalizeBasePath(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '/') {
    return '/';
  }

  final withoutTrailingSlash = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  return withoutTrailingSlash.startsWith('/')
      ? withoutTrailingSlash
      : '/$withoutTrailingSlash';
}
