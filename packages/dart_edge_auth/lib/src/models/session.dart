import 'package:dart_edge_core/dart_edge_core.dart';

import 'model_helpers.dart';

/// Public session model returned by Better Auth API routes.
final class DartEdgeAuthSession implements JsonEncodable {
  const DartEdgeAuthSession({
    required this.id,
    required this.userId,
    required this.token,
    required this.ipAddress,
    required this.userAgent,
    required this.expiresAt,
    required this.activeOrganizationId,
    required this.impersonatedBy,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthSession.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthSession(
      id: authRequiredString(json, 'id'),
      userId: authRequiredString(json, 'userId', 'user_id'),
      token: authRequiredString(json, 'token'),
      ipAddress: authString(json, 'ipAddress', 'ip_address'),
      userAgent: authString(json, 'userAgent', 'user_agent'),
      expiresAt: authRequiredDateTime(
        json,
        'expiresAt',
        fallbackKey: 'expires_at',
      ),
      activeOrganizationId: authString(
        json,
        'activeOrganizationId',
        'active_organization_id',
      ),
      impersonatedBy: authString(json, 'impersonatedBy', 'impersonated_by'),
      active: authBool(json, 'active', defaultValue: true),
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

  static const schemaId = 'DartEdgeAuthSession';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'expiresAt': JsonSchema.string(format: 'date-time'),
      'token': JsonSchema.string(),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
      'ipAddress': JsonSchema.string(nullable: true),
      'userAgent': JsonSchema.string(nullable: true),
      'userId': JsonSchema.string(),
      'impersonatedBy': JsonSchema.string(nullable: true),
      'activeOrganizationId': JsonSchema.string(nullable: true),
    },
    required: <String>[
      'id',
      'expiresAt',
      'token',
      'createdAt',
      'updatedAt',
      'ipAddress',
      'userAgent',
      'userId',
      'impersonatedBy',
      'activeOrganizationId',
    ],
    additionalProperties: false,
  );

  final String id;
  final String userId;
  final String token;
  final String? ipAddress;
  final String? userAgent;
  final DateTime expiresAt;
  final String? activeOrganizationId;
  final String? impersonatedBy;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'expiresAt': expiresAt.toIso8601String(),
    'token': token,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'userId': userId,
    'impersonatedBy': impersonatedBy,
    'activeOrganizationId': activeOrganizationId,
  };

  @override
  String toString() {
    return 'DartEdgeAuthSession(id: $id, userId: $userId, active: $active)';
  }
}
