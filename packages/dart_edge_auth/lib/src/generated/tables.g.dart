// GENERATED CODE - DO NOT MODIFY BY HAND.

import 'package:dart_edge_core/dart_edge_core.dart';

final class DartEdgeAuthSessionRow implements JsonEncodable {
  const DartEdgeAuthSessionRow({
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

  factory DartEdgeAuthSessionRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthSessionRow(
        id: row.read<String>('${prefix}id'),
        userId: row.read<String>('${prefix}user_id'),
        token: row.read<String>('${prefix}token'),
        ipAddress: row.readNullable<String>('${prefix}ip_address'),
        userAgent: row.readNullable<String>('${prefix}user_agent'),
        expiresAt: row.read<String>('${prefix}expires_at'),
        activeOrganizationId: row.readNullable<String>(
          '${prefix}active_organization_id',
        ),
        impersonatedBy: row.readNullable<String>('${prefix}impersonated_by'),
        active: row.read<bool>('${prefix}active'),
        createdAt: row.read<String>('${prefix}created_at'),
        updatedAt: row.read<String>('${prefix}updated_at'),
      );

  factory DartEdgeAuthSessionRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeAuthSessionRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeAuthSessionRow.decode(Object? value) =>
      DartEdgeAuthSessionRow.fromJson(readJsonObject(value));

  factory DartEdgeAuthSessionRow.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthSessionRow(
        id: (json['id'] as String),
        userId: (json['user_id'] as String),
        token: (json['token'] as String),
        ipAddress: json['ip_address'] == null
            ? null
            : (json['ip_address'] as String),
        userAgent: json['user_agent'] == null
            ? null
            : (json['user_agent'] as String),
        expiresAt: (json['expires_at'] as String),
        activeOrganizationId: json['active_organization_id'] == null
            ? null
            : (json['active_organization_id'] as String),
        impersonatedBy: json['impersonated_by'] == null
            ? null
            : (json['impersonated_by'] as String),
        active: (json['active'] as bool),
        createdAt: (json['created_at'] as String),
        updatedAt: (json['updated_at'] as String),
      );

  static const schemaId = 'DartEdgeAuthSessionRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'user_id': JsonSchema.string(),
      'token': JsonSchema.string(),
      'ip_address': JsonSchema.string(nullable: true),
      'user_agent': JsonSchema.string(nullable: true),
      'expires_at': JsonSchema.string(),
      'active_organization_id': JsonSchema.string(nullable: true),
      'impersonated_by': JsonSchema.string(nullable: true),
      'active': JsonSchema.boolean(),
      'created_at': JsonSchema.string(),
      'updated_at': JsonSchema.string(),
    },
    required: <String>[
      'id',
      'user_id',
      'token',
      'ip_address',
      'user_agent',
      'expires_at',
      'active_organization_id',
      'impersonated_by',
      'active',
      'created_at',
      'updated_at',
    ],
    additionalProperties: false,
  );

  final String id;

  final String userId;

  final String token;

  final String? ipAddress;

  final String? userAgent;

  final String expiresAt;

  final String? activeOrganizationId;

  final String? impersonatedBy;

  final bool active;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthSessionRow copyWith({
    String? id,
    String? userId,
    String? token,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    String? expiresAt,
    SqlValue<String?>? activeOrganizationId,
    SqlValue<String?>? impersonatedBy,
    bool? active,
    String? createdAt,
    String? updatedAt,
  }) {
    return DartEdgeAuthSessionRow(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      ipAddress: ipAddress == null || !ipAddress.isPresent
          ? this.ipAddress
          : ipAddress.value,
      userAgent: userAgent == null || !userAgent.isPresent
          ? this.userAgent
          : userAgent.value,
      expiresAt: expiresAt ?? this.expiresAt,
      activeOrganizationId:
          activeOrganizationId == null || !activeOrganizationId.isPresent
          ? this.activeOrganizationId
          : activeOrganizationId.value,
      impersonatedBy: impersonatedBy == null || !impersonatedBy.isPresent
          ? this.impersonatedBy
          : impersonatedBy.value,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'token': token,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'expires_at': expiresAt,
    'active_organization_id': activeOrganizationId,
    'impersonated_by': impersonatedBy,
    'active': active,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'user_id': userId,
    'token': token,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'expires_at': expiresAt,
    'active_organization_id': activeOrganizationId,
    'impersonated_by': impersonatedBy,
    'active': active,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionRow(id: $id, userId: $userId, token: $token, ipAddress: $ipAddress, userAgent: $userAgent, expiresAt: $expiresAt, activeOrganizationId: $activeOrganizationId, impersonatedBy: $impersonatedBy, active: $active, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthSessionInsert implements JsonEncodable {
  const DartEdgeAuthSessionInsert({
    this.id = const SqlValue.absent(),
    required this.userId,
    required this.token,
    required this.ipAddress,
    required this.userAgent,
    required this.expiresAt,
    required this.activeOrganizationId,
    required this.impersonatedBy,
    this.active = const SqlValue.absent(),
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthSessionInsert.decode(Object? value) =>
      DartEdgeAuthSessionInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthSessionInsert.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthSessionInsert(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        userId: (json['user_id'] as String),
        token: (json['token'] as String),
        ipAddress: json['ip_address'] == null
            ? null
            : (json['ip_address'] as String),
        userAgent: json['user_agent'] == null
            ? null
            : (json['user_agent'] as String),
        expiresAt: (json['expires_at'] as String),
        activeOrganizationId: json['active_organization_id'] == null
            ? null
            : (json['active_organization_id'] as String),
        impersonatedBy: json['impersonated_by'] == null
            ? null
            : (json['impersonated_by'] as String),
        active: json.containsKey('active')
            ? SqlValue<bool>((json['active'] as bool))
            : const SqlValue.absent(),
        createdAt: (json['created_at'] as String),
        updatedAt: (json['updated_at'] as String),
      );

  static const schemaId = 'DartEdgeAuthSessionInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'user_id': JsonSchema.string(),
      'token': JsonSchema.string(),
      'ip_address': JsonSchema.string(nullable: true),
      'user_agent': JsonSchema.string(nullable: true),
      'expires_at': JsonSchema.string(),
      'active_organization_id': JsonSchema.string(nullable: true),
      'impersonated_by': JsonSchema.string(nullable: true),
      'active': JsonSchema.boolean(),
      'created_at': JsonSchema.string(),
      'updated_at': JsonSchema.string(),
    },
    required: <String>[
      'user_id',
      'token',
      'ip_address',
      'user_agent',
      'expires_at',
      'active_organization_id',
      'impersonated_by',
      'created_at',
      'updated_at',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String userId;

  final String token;

  final String? ipAddress;

  final String? userAgent;

  final String expiresAt;

  final String? activeOrganizationId;

  final String? impersonatedBy;

  final SqlValue<bool> active;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthSessionInsert copyWith({
    SqlValue<String>? id,
    String? userId,
    String? token,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    String? expiresAt,
    SqlValue<String?>? activeOrganizationId,
    SqlValue<String?>? impersonatedBy,
    SqlValue<bool>? active,
    String? createdAt,
    String? updatedAt,
  }) {
    return DartEdgeAuthSessionInsert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      ipAddress: ipAddress == null || !ipAddress.isPresent
          ? this.ipAddress
          : ipAddress.value,
      userAgent: userAgent == null || !userAgent.isPresent
          ? this.userAgent
          : userAgent.value,
      expiresAt: expiresAt ?? this.expiresAt,
      activeOrganizationId:
          activeOrganizationId == null || !activeOrganizationId.isPresent
          ? this.activeOrganizationId
          : activeOrganizationId.value,
      impersonatedBy: impersonatedBy == null || !impersonatedBy.isPresent
          ? this.impersonatedBy
          : impersonatedBy.value,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'user_id': userId,
    'token': token,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'expires_at': expiresAt,
    'active_organization_id': activeOrganizationId,
    'impersonated_by': impersonatedBy,
    if (active.isPresent) 'active': active.value,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'user_id': userId,
    'token': token,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'expires_at': expiresAt,
    'active_organization_id': activeOrganizationId,
    'impersonated_by': impersonatedBy,
    if (active.isPresent) 'active': active.value,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionInsert(id: $id, userId: $userId, token: $token, ipAddress: $ipAddress, userAgent: $userAgent, expiresAt: $expiresAt, activeOrganizationId: $activeOrganizationId, impersonatedBy: $impersonatedBy, active: $active, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthSessionUpdate implements JsonEncodable {
  const DartEdgeAuthSessionUpdate({
    this.id = const SqlValue.absent(),
    this.userId = const SqlValue.absent(),
    this.token = const SqlValue.absent(),
    this.ipAddress = const SqlValue.absent(),
    this.userAgent = const SqlValue.absent(),
    this.expiresAt = const SqlValue.absent(),
    this.activeOrganizationId = const SqlValue.absent(),
    this.impersonatedBy = const SqlValue.absent(),
    this.active = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.updatedAt = const SqlValue.absent(),
  });

  factory DartEdgeAuthSessionUpdate.decode(Object? value) =>
      DartEdgeAuthSessionUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthSessionUpdate.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthSessionUpdate(
    id: json.containsKey('id')
        ? SqlValue<String>((json['id'] as String))
        : const SqlValue.absent(),
    userId: json.containsKey('user_id')
        ? SqlValue<String>((json['user_id'] as String))
        : const SqlValue.absent(),
    token: json.containsKey('token')
        ? SqlValue<String>((json['token'] as String))
        : const SqlValue.absent(),
    ipAddress: json.containsKey('ip_address')
        ? SqlValue<String?>(
            json['ip_address'] == null ? null : (json['ip_address'] as String),
          )
        : const SqlValue.absent(),
    userAgent: json.containsKey('user_agent')
        ? SqlValue<String?>(
            json['user_agent'] == null ? null : (json['user_agent'] as String),
          )
        : const SqlValue.absent(),
    expiresAt: json.containsKey('expires_at')
        ? SqlValue<String>((json['expires_at'] as String))
        : const SqlValue.absent(),
    activeOrganizationId: json.containsKey('active_organization_id')
        ? SqlValue<String?>(
            json['active_organization_id'] == null
                ? null
                : (json['active_organization_id'] as String),
          )
        : const SqlValue.absent(),
    impersonatedBy: json.containsKey('impersonated_by')
        ? SqlValue<String?>(
            json['impersonated_by'] == null
                ? null
                : (json['impersonated_by'] as String),
          )
        : const SqlValue.absent(),
    active: json.containsKey('active')
        ? SqlValue<bool>((json['active'] as bool))
        : const SqlValue.absent(),
    createdAt: json.containsKey('created_at')
        ? SqlValue<String>((json['created_at'] as String))
        : const SqlValue.absent(),
    updatedAt: json.containsKey('updated_at')
        ? SqlValue<String>((json['updated_at'] as String))
        : const SqlValue.absent(),
  );

  static const schemaId = 'DartEdgeAuthSessionUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'user_id': JsonSchema.string(),
      'token': JsonSchema.string(),
      'ip_address': JsonSchema.string(nullable: true),
      'user_agent': JsonSchema.string(nullable: true),
      'expires_at': JsonSchema.string(),
      'active_organization_id': JsonSchema.string(nullable: true),
      'impersonated_by': JsonSchema.string(nullable: true),
      'active': JsonSchema.boolean(),
      'created_at': JsonSchema.string(),
      'updated_at': JsonSchema.string(),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<String> userId;

  final SqlValue<String> token;

  final SqlValue<String?> ipAddress;

  final SqlValue<String?> userAgent;

  final SqlValue<String> expiresAt;

  final SqlValue<String?> activeOrganizationId;

  final SqlValue<String?> impersonatedBy;

  final SqlValue<bool> active;

  final SqlValue<String> createdAt;

  final SqlValue<String> updatedAt;

  DartEdgeAuthSessionUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String>? userId,
    SqlValue<String>? token,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    SqlValue<String>? expiresAt,
    SqlValue<String?>? activeOrganizationId,
    SqlValue<String?>? impersonatedBy,
    SqlValue<bool>? active,
    SqlValue<String>? createdAt,
    SqlValue<String>? updatedAt,
  }) {
    return DartEdgeAuthSessionUpdate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      expiresAt: expiresAt ?? this.expiresAt,
      activeOrganizationId: activeOrganizationId ?? this.activeOrganizationId,
      impersonatedBy: impersonatedBy ?? this.impersonatedBy,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (userId.isPresent) 'user_id': userId.value,
    if (token.isPresent) 'token': token.value,
    if (ipAddress.isPresent) 'ip_address': ipAddress.value,
    if (userAgent.isPresent) 'user_agent': userAgent.value,
    if (expiresAt.isPresent) 'expires_at': expiresAt.value,
    if (activeOrganizationId.isPresent)
      'active_organization_id': activeOrganizationId.value,
    if (impersonatedBy.isPresent) 'impersonated_by': impersonatedBy.value,
    if (active.isPresent) 'active': active.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
    if (updatedAt.isPresent) 'updated_at': updatedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (userId.isPresent) 'user_id': userId.value,
    if (token.isPresent) 'token': token.value,
    if (ipAddress.isPresent) 'ip_address': ipAddress.value,
    if (userAgent.isPresent) 'user_agent': userAgent.value,
    if (expiresAt.isPresent) 'expires_at': expiresAt.value,
    if (activeOrganizationId.isPresent)
      'active_organization_id': activeOrganizationId.value,
    if (impersonatedBy.isPresent) 'impersonated_by': impersonatedBy.value,
    if (active.isPresent) 'active': active.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
    if (updatedAt.isPresent) 'updated_at': updatedAt.value,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionUpdate(id: $id, userId: $userId, token: $token, ipAddress: $ipAddress, userAgent: $userAgent, expiresAt: $expiresAt, activeOrganizationId: $activeOrganizationId, impersonatedBy: $impersonatedBy, active: $active, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthSessionsTable
    extends
        SqlTable<
          DartEdgeAuthSessionRow,
          DartEdgeAuthSessionInsert,
          DartEdgeAuthSessionUpdate
        > {
  const DartEdgeAuthSessionsTable._() : schema = null;

  const DartEdgeAuthSessionsTable.withSchema(this.schema);

  @override
  final String? schema;

  static const table = DartEdgeAuthSessionsTable._();

  static final id = SqlColumn<String>(
    table: table,
    name: 'id',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final userId = SqlColumn<String>(
    table: table,
    name: 'user_id',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final token = SqlColumn<String>(
    table: table,
    name: 'token',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final ipAddress = SqlColumn<String>(
    table: table,
    name: 'ip_address',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final userAgent = SqlColumn<String>(
    table: table,
    name: 'user_agent',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final expiresAt = SqlColumn<String>(
    table: table,
    name: 'expires_at',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final activeOrganizationId = SqlColumn<String>(
    table: table,
    name: 'active_organization_id',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final impersonatedBy = SqlColumn<String>(
    table: table,
    name: 'impersonated_by',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final active = SqlColumn<bool>(
    table: table,
    name: 'active',
    nullable: false,
    databaseType: 'BOOLEAN',
  );

  static final createdAt = SqlColumn<String>(
    table: table,
    name: 'created_at',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final updatedAt = SqlColumn<String>(
    table: table,
    name: 'updated_at',
    nullable: false,
    databaseType: 'TEXT',
  );

  @override
  String get name => 'session';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'TEXT').asObjectColumn,
    column<String>(
      'user_id',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'token',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'ip_address',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'user_agent',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'expires_at',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'active_organization_id',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'impersonated_by',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<bool>(
      'active',
      nullable: false,
      databaseType: 'BOOLEAN',
    ).asObjectColumn,
    column<String>(
      'created_at',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'updated_at',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
  ];

  @override
  DartEdgeAuthSessionRow mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthSessionRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(DartEdgeAuthSessionInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(DartEdgeAuthSessionUpdate value) =>
      value.toColumns();
}

extension DartEdgeAuthSessionsTableColumns on DartEdgeAuthSessionsTable {
  SqlColumn<String> get id =>
      column<String>('id', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get userId =>
      column<String>('user_id', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get token =>
      column<String>('token', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get ipAddress =>
      column<String>('ip_address', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get userAgent =>
      column<String>('user_agent', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get expiresAt =>
      column<String>('expires_at', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get activeOrganizationId => column<String>(
    'active_organization_id',
    nullable: true,
    databaseType: 'TEXT',
  );

  SqlColumn<String> get impersonatedBy =>
      column<String>('impersonated_by', nullable: true, databaseType: 'TEXT');

  SqlColumn<bool> get active =>
      column<bool>('active', nullable: false, databaseType: 'BOOLEAN');

  SqlColumn<String> get createdAt =>
      column<String>('created_at', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get updatedAt =>
      column<String>('updated_at', nullable: false, databaseType: 'TEXT');
}

final class DartEdgeAuthUserRow implements JsonEncodable {
  const DartEdgeAuthUserRow({
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

  factory DartEdgeAuthUserRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthUserRow(
        id: row.read<String>('${prefix}id'),
        name: row.readNullable<String>('${prefix}name'),
        email: row.read<String>('${prefix}email'),
        username: row.readNullable<String>('${prefix}username'),
        displayUsername: row.readNullable<String>('${prefix}display_username'),
        emailVerified: row.read<bool>('${prefix}email_verified'),
        image: row.readNullable<String>('${prefix}image'),
        role: row.read<String>('${prefix}role'),
        banned: row.read<bool>('${prefix}banned'),
        banReason: row.readNullable<String>('${prefix}ban_reason'),
        banExpires: row.readNullable<String>('${prefix}ban_expires'),
        twoFactorEnabled: row.read<bool>('${prefix}two_factor_enabled'),
        metadata: row.readNullable<String>('${prefix}metadata'),
        createdAt: row.read<String>('${prefix}created_at'),
        updatedAt: row.read<String>('${prefix}updated_at'),
      );

  factory DartEdgeAuthUserRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeAuthUserRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeAuthUserRow.decode(Object? value) =>
      DartEdgeAuthUserRow.fromJson(readJsonObject(value));

  factory DartEdgeAuthUserRow.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthUserRow(
    id: (json['id'] as String),
    name: json['name'] == null ? null : (json['name'] as String),
    email: (json['email'] as String),
    username: json['username'] == null ? null : (json['username'] as String),
    displayUsername: json['display_username'] == null
        ? null
        : (json['display_username'] as String),
    emailVerified: (json['email_verified'] as bool),
    image: json['image'] == null ? null : (json['image'] as String),
    role: (json['role'] as String),
    banned: (json['banned'] as bool),
    banReason: json['ban_reason'] == null
        ? null
        : (json['ban_reason'] as String),
    banExpires: json['ban_expires'] == null
        ? null
        : (json['ban_expires'] as String),
    twoFactorEnabled: (json['two_factor_enabled'] as bool),
    metadata: json['metadata'] == null ? null : (json['metadata'] as String),
    createdAt: (json['created_at'] as String),
    updatedAt: (json['updated_at'] as String),
  );

  static const schemaId = 'DartEdgeAuthUserRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(nullable: true),
      'email': JsonSchema.string(),
      'username': JsonSchema.string(nullable: true),
      'display_username': JsonSchema.string(nullable: true),
      'email_verified': JsonSchema.boolean(),
      'image': JsonSchema.string(nullable: true),
      'role': JsonSchema.string(),
      'banned': JsonSchema.boolean(),
      'ban_reason': JsonSchema.string(nullable: true),
      'ban_expires': JsonSchema.string(nullable: true),
      'two_factor_enabled': JsonSchema.boolean(),
      'metadata': JsonSchema.string(nullable: true),
      'created_at': JsonSchema.string(),
      'updated_at': JsonSchema.string(),
    },
    required: <String>[
      'id',
      'name',
      'email',
      'username',
      'display_username',
      'email_verified',
      'image',
      'role',
      'banned',
      'ban_reason',
      'ban_expires',
      'two_factor_enabled',
      'metadata',
      'created_at',
      'updated_at',
    ],
    additionalProperties: false,
  );

  final String id;

  final String? name;

  final String email;

  final String? username;

  final String? displayUsername;

  final bool emailVerified;

  final String? image;

  final String role;

  final bool banned;

  final String? banReason;

  final String? banExpires;

  final bool twoFactorEnabled;

  final String? metadata;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthUserRow copyWith({
    String? id,
    SqlValue<String?>? name,
    String? email,
    SqlValue<String?>? username,
    SqlValue<String?>? displayUsername,
    bool? emailVerified,
    SqlValue<String?>? image,
    String? role,
    bool? banned,
    SqlValue<String?>? banReason,
    SqlValue<String?>? banExpires,
    bool? twoFactorEnabled,
    SqlValue<String?>? metadata,
    String? createdAt,
    String? updatedAt,
  }) {
    return DartEdgeAuthUserRow(
      id: id ?? this.id,
      name: name == null || !name.isPresent ? this.name : name.value,
      email: email ?? this.email,
      username: username == null || !username.isPresent
          ? this.username
          : username.value,
      displayUsername: displayUsername == null || !displayUsername.isPresent
          ? this.displayUsername
          : displayUsername.value,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image == null || !image.isPresent ? this.image : image.value,
      role: role ?? this.role,
      banned: banned ?? this.banned,
      banReason: banReason == null || !banReason.isPresent
          ? this.banReason
          : banReason.value,
      banExpires: banExpires == null || !banExpires.isPresent
          ? this.banExpires
          : banExpires.value,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      metadata: metadata == null || !metadata.isPresent
          ? this.metadata
          : metadata.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'username': username,
    'display_username': displayUsername,
    'email_verified': emailVerified,
    'image': image,
    'role': role,
    'banned': banned,
    'ban_reason': banReason,
    'ban_expires': banExpires,
    'two_factor_enabled': twoFactorEnabled,
    'metadata': metadata,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'username': username,
    'display_username': displayUsername,
    'email_verified': emailVerified,
    'image': image,
    'role': role,
    'banned': banned,
    'ban_reason': banReason,
    'ban_expires': banExpires,
    'two_factor_enabled': twoFactorEnabled,
    'metadata': metadata,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserRow(id: $id, name: $name, email: $email, username: $username, displayUsername: $displayUsername, emailVerified: $emailVerified, image: $image, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, twoFactorEnabled: $twoFactorEnabled, metadata: $metadata, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthUserInsert implements JsonEncodable {
  const DartEdgeAuthUserInsert({
    this.id = const SqlValue.absent(),
    required this.name,
    required this.email,
    required this.username,
    required this.displayUsername,
    this.emailVerified = const SqlValue.absent(),
    required this.image,
    this.role = const SqlValue.absent(),
    this.banned = const SqlValue.absent(),
    required this.banReason,
    required this.banExpires,
    this.twoFactorEnabled = const SqlValue.absent(),
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthUserInsert.decode(Object? value) =>
      DartEdgeAuthUserInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthUserInsert.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthUserInsert(
    id: json.containsKey('id')
        ? SqlValue<String>((json['id'] as String))
        : const SqlValue.absent(),
    name: json['name'] == null ? null : (json['name'] as String),
    email: (json['email'] as String),
    username: json['username'] == null ? null : (json['username'] as String),
    displayUsername: json['display_username'] == null
        ? null
        : (json['display_username'] as String),
    emailVerified: json.containsKey('email_verified')
        ? SqlValue<bool>((json['email_verified'] as bool))
        : const SqlValue.absent(),
    image: json['image'] == null ? null : (json['image'] as String),
    role: json.containsKey('role')
        ? SqlValue<String>((json['role'] as String))
        : const SqlValue.absent(),
    banned: json.containsKey('banned')
        ? SqlValue<bool>((json['banned'] as bool))
        : const SqlValue.absent(),
    banReason: json['ban_reason'] == null
        ? null
        : (json['ban_reason'] as String),
    banExpires: json['ban_expires'] == null
        ? null
        : (json['ban_expires'] as String),
    twoFactorEnabled: json.containsKey('two_factor_enabled')
        ? SqlValue<bool>((json['two_factor_enabled'] as bool))
        : const SqlValue.absent(),
    metadata: json['metadata'] == null ? null : (json['metadata'] as String),
    createdAt: (json['created_at'] as String),
    updatedAt: (json['updated_at'] as String),
  );

  static const schemaId = 'DartEdgeAuthUserInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(nullable: true),
      'email': JsonSchema.string(),
      'username': JsonSchema.string(nullable: true),
      'display_username': JsonSchema.string(nullable: true),
      'email_verified': JsonSchema.boolean(),
      'image': JsonSchema.string(nullable: true),
      'role': JsonSchema.string(),
      'banned': JsonSchema.boolean(),
      'ban_reason': JsonSchema.string(nullable: true),
      'ban_expires': JsonSchema.string(nullable: true),
      'two_factor_enabled': JsonSchema.boolean(),
      'metadata': JsonSchema.string(nullable: true),
      'created_at': JsonSchema.string(),
      'updated_at': JsonSchema.string(),
    },
    required: <String>[
      'name',
      'email',
      'username',
      'display_username',
      'image',
      'ban_reason',
      'ban_expires',
      'metadata',
      'created_at',
      'updated_at',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String? name;

  final String email;

  final String? username;

  final String? displayUsername;

  final SqlValue<bool> emailVerified;

  final String? image;

  final SqlValue<String> role;

  final SqlValue<bool> banned;

  final String? banReason;

  final String? banExpires;

  final SqlValue<bool> twoFactorEnabled;

  final String? metadata;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthUserInsert copyWith({
    SqlValue<String>? id,
    SqlValue<String?>? name,
    String? email,
    SqlValue<String?>? username,
    SqlValue<String?>? displayUsername,
    SqlValue<bool>? emailVerified,
    SqlValue<String?>? image,
    SqlValue<String>? role,
    SqlValue<bool>? banned,
    SqlValue<String?>? banReason,
    SqlValue<String?>? banExpires,
    SqlValue<bool>? twoFactorEnabled,
    SqlValue<String?>? metadata,
    String? createdAt,
    String? updatedAt,
  }) {
    return DartEdgeAuthUserInsert(
      id: id ?? this.id,
      name: name == null || !name.isPresent ? this.name : name.value,
      email: email ?? this.email,
      username: username == null || !username.isPresent
          ? this.username
          : username.value,
      displayUsername: displayUsername == null || !displayUsername.isPresent
          ? this.displayUsername
          : displayUsername.value,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image == null || !image.isPresent ? this.image : image.value,
      role: role ?? this.role,
      banned: banned ?? this.banned,
      banReason: banReason == null || !banReason.isPresent
          ? this.banReason
          : banReason.value,
      banExpires: banExpires == null || !banExpires.isPresent
          ? this.banExpires
          : banExpires.value,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      metadata: metadata == null || !metadata.isPresent
          ? this.metadata
          : metadata.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
    'username': username,
    'display_username': displayUsername,
    if (emailVerified.isPresent) 'email_verified': emailVerified.value,
    'image': image,
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    'ban_reason': banReason,
    'ban_expires': banExpires,
    if (twoFactorEnabled.isPresent)
      'two_factor_enabled': twoFactorEnabled.value,
    'metadata': metadata,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
    'username': username,
    'display_username': displayUsername,
    if (emailVerified.isPresent) 'email_verified': emailVerified.value,
    'image': image,
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    'ban_reason': banReason,
    'ban_expires': banExpires,
    if (twoFactorEnabled.isPresent)
      'two_factor_enabled': twoFactorEnabled.value,
    'metadata': metadata,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserInsert(id: $id, name: $name, email: $email, username: $username, displayUsername: $displayUsername, emailVerified: $emailVerified, image: $image, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, twoFactorEnabled: $twoFactorEnabled, metadata: $metadata, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthUserUpdate implements JsonEncodable {
  const DartEdgeAuthUserUpdate({
    this.id = const SqlValue.absent(),
    this.name = const SqlValue.absent(),
    this.email = const SqlValue.absent(),
    this.username = const SqlValue.absent(),
    this.displayUsername = const SqlValue.absent(),
    this.emailVerified = const SqlValue.absent(),
    this.image = const SqlValue.absent(),
    this.role = const SqlValue.absent(),
    this.banned = const SqlValue.absent(),
    this.banReason = const SqlValue.absent(),
    this.banExpires = const SqlValue.absent(),
    this.twoFactorEnabled = const SqlValue.absent(),
    this.metadata = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.updatedAt = const SqlValue.absent(),
  });

  factory DartEdgeAuthUserUpdate.decode(Object? value) =>
      DartEdgeAuthUserUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthUserUpdate.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthUserUpdate(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        name: json.containsKey('name')
            ? SqlValue<String?>(
                json['name'] == null ? null : (json['name'] as String),
              )
            : const SqlValue.absent(),
        email: json.containsKey('email')
            ? SqlValue<String>((json['email'] as String))
            : const SqlValue.absent(),
        username: json.containsKey('username')
            ? SqlValue<String?>(
                json['username'] == null ? null : (json['username'] as String),
              )
            : const SqlValue.absent(),
        displayUsername: json.containsKey('display_username')
            ? SqlValue<String?>(
                json['display_username'] == null
                    ? null
                    : (json['display_username'] as String),
              )
            : const SqlValue.absent(),
        emailVerified: json.containsKey('email_verified')
            ? SqlValue<bool>((json['email_verified'] as bool))
            : const SqlValue.absent(),
        image: json.containsKey('image')
            ? SqlValue<String?>(
                json['image'] == null ? null : (json['image'] as String),
              )
            : const SqlValue.absent(),
        role: json.containsKey('role')
            ? SqlValue<String>((json['role'] as String))
            : const SqlValue.absent(),
        banned: json.containsKey('banned')
            ? SqlValue<bool>((json['banned'] as bool))
            : const SqlValue.absent(),
        banReason: json.containsKey('ban_reason')
            ? SqlValue<String?>(
                json['ban_reason'] == null
                    ? null
                    : (json['ban_reason'] as String),
              )
            : const SqlValue.absent(),
        banExpires: json.containsKey('ban_expires')
            ? SqlValue<String?>(
                json['ban_expires'] == null
                    ? null
                    : (json['ban_expires'] as String),
              )
            : const SqlValue.absent(),
        twoFactorEnabled: json.containsKey('two_factor_enabled')
            ? SqlValue<bool>((json['two_factor_enabled'] as bool))
            : const SqlValue.absent(),
        metadata: json.containsKey('metadata')
            ? SqlValue<String?>(
                json['metadata'] == null ? null : (json['metadata'] as String),
              )
            : const SqlValue.absent(),
        createdAt: json.containsKey('created_at')
            ? SqlValue<String>((json['created_at'] as String))
            : const SqlValue.absent(),
        updatedAt: json.containsKey('updated_at')
            ? SqlValue<String>((json['updated_at'] as String))
            : const SqlValue.absent(),
      );

  static const schemaId = 'DartEdgeAuthUserUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(nullable: true),
      'email': JsonSchema.string(),
      'username': JsonSchema.string(nullable: true),
      'display_username': JsonSchema.string(nullable: true),
      'email_verified': JsonSchema.boolean(),
      'image': JsonSchema.string(nullable: true),
      'role': JsonSchema.string(),
      'banned': JsonSchema.boolean(),
      'ban_reason': JsonSchema.string(nullable: true),
      'ban_expires': JsonSchema.string(nullable: true),
      'two_factor_enabled': JsonSchema.boolean(),
      'metadata': JsonSchema.string(nullable: true),
      'created_at': JsonSchema.string(),
      'updated_at': JsonSchema.string(),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<String?> name;

  final SqlValue<String> email;

  final SqlValue<String?> username;

  final SqlValue<String?> displayUsername;

  final SqlValue<bool> emailVerified;

  final SqlValue<String?> image;

  final SqlValue<String> role;

  final SqlValue<bool> banned;

  final SqlValue<String?> banReason;

  final SqlValue<String?> banExpires;

  final SqlValue<bool> twoFactorEnabled;

  final SqlValue<String?> metadata;

  final SqlValue<String> createdAt;

  final SqlValue<String> updatedAt;

  DartEdgeAuthUserUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String?>? name,
    SqlValue<String>? email,
    SqlValue<String?>? username,
    SqlValue<String?>? displayUsername,
    SqlValue<bool>? emailVerified,
    SqlValue<String?>? image,
    SqlValue<String>? role,
    SqlValue<bool>? banned,
    SqlValue<String?>? banReason,
    SqlValue<String?>? banExpires,
    SqlValue<bool>? twoFactorEnabled,
    SqlValue<String?>? metadata,
    SqlValue<String>? createdAt,
    SqlValue<String>? updatedAt,
  }) {
    return DartEdgeAuthUserUpdate(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      displayUsername: displayUsername ?? this.displayUsername,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image ?? this.image,
      role: role ?? this.role,
      banned: banned ?? this.banned,
      banReason: banReason ?? this.banReason,
      banExpires: banExpires ?? this.banExpires,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (username.isPresent) 'username': username.value,
    if (displayUsername.isPresent) 'display_username': displayUsername.value,
    if (emailVerified.isPresent) 'email_verified': emailVerified.value,
    if (image.isPresent) 'image': image.value,
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    if (banReason.isPresent) 'ban_reason': banReason.value,
    if (banExpires.isPresent) 'ban_expires': banExpires.value,
    if (twoFactorEnabled.isPresent)
      'two_factor_enabled': twoFactorEnabled.value,
    if (metadata.isPresent) 'metadata': metadata.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
    if (updatedAt.isPresent) 'updated_at': updatedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (username.isPresent) 'username': username.value,
    if (displayUsername.isPresent) 'display_username': displayUsername.value,
    if (emailVerified.isPresent) 'email_verified': emailVerified.value,
    if (image.isPresent) 'image': image.value,
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    if (banReason.isPresent) 'ban_reason': banReason.value,
    if (banExpires.isPresent) 'ban_expires': banExpires.value,
    if (twoFactorEnabled.isPresent)
      'two_factor_enabled': twoFactorEnabled.value,
    if (metadata.isPresent) 'metadata': metadata.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
    if (updatedAt.isPresent) 'updated_at': updatedAt.value,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserUpdate(id: $id, name: $name, email: $email, username: $username, displayUsername: $displayUsername, emailVerified: $emailVerified, image: $image, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, twoFactorEnabled: $twoFactorEnabled, metadata: $metadata, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthUsersTable
    extends
        SqlTable<
          DartEdgeAuthUserRow,
          DartEdgeAuthUserInsert,
          DartEdgeAuthUserUpdate
        > {
  const DartEdgeAuthUsersTable._() : schema = null;

  const DartEdgeAuthUsersTable.withSchema(this.schema);

  @override
  final String? schema;

  static const table = DartEdgeAuthUsersTable._();

  static final id = SqlColumn<String>(
    table: table,
    name: 'id',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final nameColumn = SqlColumn<String>(
    table: table,
    name: 'name',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final email = SqlColumn<String>(
    table: table,
    name: 'email',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final username = SqlColumn<String>(
    table: table,
    name: 'username',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final displayUsername = SqlColumn<String>(
    table: table,
    name: 'display_username',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final emailVerified = SqlColumn<bool>(
    table: table,
    name: 'email_verified',
    nullable: false,
    databaseType: 'BOOLEAN',
  );

  static final image = SqlColumn<String>(
    table: table,
    name: 'image',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final role = SqlColumn<String>(
    table: table,
    name: 'role',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final banned = SqlColumn<bool>(
    table: table,
    name: 'banned',
    nullable: false,
    databaseType: 'BOOLEAN',
  );

  static final banReason = SqlColumn<String>(
    table: table,
    name: 'ban_reason',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final banExpires = SqlColumn<String>(
    table: table,
    name: 'ban_expires',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final twoFactorEnabled = SqlColumn<bool>(
    table: table,
    name: 'two_factor_enabled',
    nullable: false,
    databaseType: 'BOOLEAN',
  );

  static final metadata = SqlColumn<String>(
    table: table,
    name: 'metadata',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final createdAt = SqlColumn<String>(
    table: table,
    name: 'created_at',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final updatedAt = SqlColumn<String>(
    table: table,
    name: 'updated_at',
    nullable: false,
    databaseType: 'TEXT',
  );

  @override
  String get name => 'user';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'TEXT').asObjectColumn,
    column<String>('name', nullable: true, databaseType: 'TEXT').asObjectColumn,
    column<String>(
      'email',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'username',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'display_username',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<bool>(
      'email_verified',
      nullable: false,
      databaseType: 'BOOLEAN',
    ).asObjectColumn,
    column<String>(
      'image',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'role',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<bool>(
      'banned',
      nullable: false,
      databaseType: 'BOOLEAN',
    ).asObjectColumn,
    column<String>(
      'ban_reason',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'ban_expires',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<bool>(
      'two_factor_enabled',
      nullable: false,
      databaseType: 'BOOLEAN',
    ).asObjectColumn,
    column<String>(
      'metadata',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'created_at',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'updated_at',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
  ];

  @override
  DartEdgeAuthUserRow mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthUserRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(DartEdgeAuthUserInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(DartEdgeAuthUserUpdate value) =>
      value.toColumns();
}

extension DartEdgeAuthUsersTableColumns on DartEdgeAuthUsersTable {
  SqlColumn<String> get id =>
      column<String>('id', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get nameColumn =>
      column<String>('name', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get email =>
      column<String>('email', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get username =>
      column<String>('username', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get displayUsername =>
      column<String>('display_username', nullable: true, databaseType: 'TEXT');

  SqlColumn<bool> get emailVerified =>
      column<bool>('email_verified', nullable: false, databaseType: 'BOOLEAN');

  SqlColumn<String> get image =>
      column<String>('image', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get role =>
      column<String>('role', nullable: false, databaseType: 'TEXT');

  SqlColumn<bool> get banned =>
      column<bool>('banned', nullable: false, databaseType: 'BOOLEAN');

  SqlColumn<String> get banReason =>
      column<String>('ban_reason', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get banExpires =>
      column<String>('ban_expires', nullable: true, databaseType: 'TEXT');

  SqlColumn<bool> get twoFactorEnabled => column<bool>(
    'two_factor_enabled',
    nullable: false,
    databaseType: 'BOOLEAN',
  );

  SqlColumn<String> get metadata =>
      column<String>('metadata', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get createdAt =>
      column<String>('created_at', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get updatedAt =>
      column<String>('updated_at', nullable: false, databaseType: 'TEXT');
}
