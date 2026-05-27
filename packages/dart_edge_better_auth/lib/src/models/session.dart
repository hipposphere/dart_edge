final class BetterAuthSession {
  const BetterAuthSession({
    required this.id,
    required this.expiresAt,
    required this.token,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.ipAddress,
    this.userAgent,
    this.impersonatedBy,
  });

  final String id;
  final DateTime expiresAt;
  final String token;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ipAddress;
  final String? userAgent;
  final String userId;
  final String? impersonatedBy;

  Map<String, Object?> toJson() => {
    'id': id,
    'expiresAt': expiresAt.toIso8601String(),
    'token': token,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'userId': userId,
    if (impersonatedBy != null) 'impersonatedBy': impersonatedBy,
  };
}
