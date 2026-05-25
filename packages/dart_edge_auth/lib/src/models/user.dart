import 'package:dart_edge_core/dart_edge_core.dart';

import 'model_helpers.dart';

/// Public user model returned by Better Auth API routes.
final class DartEdgeAuthUser implements JsonEncodable {
  const DartEdgeAuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.displayUsername,
    required this.emailVerified,
    required this.image,
    required this.role,
    required this.banned,
    required this.banReason,
    required this.banExpires,
    required this.twoFactorEnabled,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthUser.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthUser(
      id: authRequiredString(json, 'id'),
      name: authString(json, 'name'),
      email: authString(json, 'email'),
      username: authString(json, 'username'),
      displayUsername: authString(json, 'displayUsername', 'display_username'),
      emailVerified: authBool(
        json,
        'emailVerified',
        fallbackKey: 'email_verified',
      ),
      image: authString(json, 'image'),
      role: authString(json, 'role'),
      banned: authBool(json, 'banned'),
      banReason: authString(json, 'banReason', 'ban_reason'),
      banExpires: authDateTime(json, 'banExpires', fallbackKey: 'ban_expires'),
      twoFactorEnabled: authBool(
        json,
        'twoFactorEnabled',
        fallbackKey: 'two_factor_enabled',
      ),
      metadata: authJsonValue(authJsonLookup(json, 'metadata')),
      createdAt: authRequiredDateTime(
        json,
        'createdAt',
        fallbackKey: 'created_at',
      ),
      updatedAt: authRequiredDateTime(
        json,
        'updatedAt',
        fallbackKey: 'updated_at',
      ),
    );
  }

  static const schemaId = 'DartEdgeAuthUser';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(nullable: true),
      'email': JsonSchema.string(nullable: true),
      'emailVerified': JsonSchema.boolean(),
      'image': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
      'username': JsonSchema.string(nullable: true),
      'displayUsername': JsonSchema.string(nullable: true),
      'twoFactorEnabled': JsonSchema.boolean(),
      'role': JsonSchema.string(nullable: true),
      'banned': JsonSchema.boolean(),
      'banReason': JsonSchema.string(nullable: true),
      'banExpires': JsonSchema.string(nullable: true, format: 'date-time'),
    },
    required: <String>[
      'id',
      'name',
      'email',
      'emailVerified',
      'image',
      'createdAt',
      'updatedAt',
      'username',
      'displayUsername',
      'twoFactorEnabled',
      'role',
      'banned',
      'banReason',
      'banExpires',
    ],
    additionalProperties: false,
  );

  final String id;
  final String? name;
  final String? email;
  final String? username;
  final String? displayUsername;
  final bool emailVerified;
  final String? image;
  final String? role;
  final bool banned;
  final String? banReason;
  final DateTime? banExpires;
  final bool twoFactorEnabled;
  final Object? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'username': username,
    'displayUsername': displayUsername,
    'twoFactorEnabled': twoFactorEnabled,
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires?.toIso8601String(),
  };

  @override
  String toString() {
    return 'DartEdgeAuthUser(id: $id, email: $email, role: $role)';
  }
}
