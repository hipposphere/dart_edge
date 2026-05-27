final class BetterAuthUser {
  const BetterAuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.image,
    this.role,
    this.banned,
    this.banReason,
    this.banExpires,
    this.phoneNumber,
    this.phoneNumberVerified,
  });

  final String id;
  final String name;
  final String email;
  final bool emailVerified;
  final String? image;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? role;
  final bool? banned;
  final String? banReason;
  final DateTime? banExpires;
  final String? phoneNumber;
  final bool? phoneNumberVerified;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (role != null) 'role': role,
    if (banned != null) 'banned': banned,
    if (banReason != null) 'banReason': banReason,
    if (banExpires != null) 'banExpires': banExpires!.toIso8601String(),
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (phoneNumberVerified != null) 'phoneNumberVerified': phoneNumberVerified,
  };
}
