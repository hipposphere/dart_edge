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
    required this.impersonatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthSessionRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthSessionRow(
        id: row.read<String>('${prefix}id'),
        userId: row.read<String>('${prefix}userId'),
        token: row.read<String>('${prefix}token'),
        ipAddress: row.readNullable<String>('${prefix}ipAddress'),
        userAgent: row.readNullable<String>('${prefix}userAgent'),
        expiresAt: row.read<String>('${prefix}expiresAt'),
        impersonatedBy: row.readNullable<String>('${prefix}impersonatedBy'),
        createdAt: row.read<String>('${prefix}createdAt'),
        updatedAt: row.read<String>('${prefix}updatedAt'),
      );

  factory DartEdgeAuthSessionRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeAuthSessionRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeAuthSessionRow.decode(Object? value) =>
      DartEdgeAuthSessionRow.fromJson(readJsonObject(value));

  factory DartEdgeAuthSessionRow.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthSessionRow(
    id: (json['id'] as String),
    userId: (json['userId'] as String),
    token: (json['token'] as String),
    ipAddress: json['ipAddress'] == null ? null : (json['ipAddress'] as String),
    userAgent: json['userAgent'] == null ? null : (json['userAgent'] as String),
    expiresAt: (json['expiresAt'] as String),
    impersonatedBy: json['impersonatedBy'] == null
        ? null
        : (json['impersonatedBy'] as String),
    createdAt: (json['createdAt'] as String),
    updatedAt: (json['updatedAt'] as String),
  );

  static const schemaId = 'DartEdgeAuthSessionRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'token': JsonSchema.string(),
      'ipAddress': JsonSchema.string(nullable: true),
      'userAgent': JsonSchema.string(nullable: true),
      'expiresAt': JsonSchema.string(),
      'impersonatedBy': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(),
      'updatedAt': JsonSchema.string(),
    },
    required: <String>[
      'id',
      'userId',
      'token',
      'ipAddress',
      'userAgent',
      'expiresAt',
      'impersonatedBy',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final String id;

  final String userId;

  final String token;

  final String? ipAddress;

  final String? userAgent;

  final String expiresAt;

  final String? impersonatedBy;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthSessionRow copyWith({
    String? id,
    String? userId,
    String? token,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    String? expiresAt,
    SqlValue<String?>? impersonatedBy,
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
      impersonatedBy: impersonatedBy == null || !impersonatedBy.isPresent
          ? this.impersonatedBy
          : impersonatedBy.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'userId': userId,
    'token': token,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'expiresAt': expiresAt,
    'impersonatedBy': impersonatedBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'userId': userId,
    'token': token,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'expiresAt': expiresAt,
    'impersonatedBy': impersonatedBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionRow(id: $id, userId: $userId, token: $token, ipAddress: $ipAddress, userAgent: $userAgent, expiresAt: $expiresAt, impersonatedBy: $impersonatedBy, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthSessionInsert implements JsonEncodable {
  const DartEdgeAuthSessionInsert({
    this.id = const SqlValue.absent(),
    required this.userId,
    required this.token,
    required this.ipAddress,
    required this.userAgent,
    required this.expiresAt,
    required this.impersonatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthSessionInsert.decode(Object? value) =>
      DartEdgeAuthSessionInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthSessionInsert.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthSessionInsert(
    id: json.containsKey('id')
        ? SqlValue<String>((json['id'] as String))
        : const SqlValue.absent(),
    userId: (json['userId'] as String),
    token: (json['token'] as String),
    ipAddress: json['ipAddress'] == null ? null : (json['ipAddress'] as String),
    userAgent: json['userAgent'] == null ? null : (json['userAgent'] as String),
    expiresAt: (json['expiresAt'] as String),
    impersonatedBy: json['impersonatedBy'] == null
        ? null
        : (json['impersonatedBy'] as String),
    createdAt: (json['createdAt'] as String),
    updatedAt: (json['updatedAt'] as String),
  );

  static const schemaId = 'DartEdgeAuthSessionInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'token': JsonSchema.string(),
      'ipAddress': JsonSchema.string(nullable: true),
      'userAgent': JsonSchema.string(nullable: true),
      'expiresAt': JsonSchema.string(),
      'impersonatedBy': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(),
      'updatedAt': JsonSchema.string(),
    },
    required: <String>[
      'userId',
      'token',
      'ipAddress',
      'userAgent',
      'expiresAt',
      'impersonatedBy',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String userId;

  final String token;

  final String? ipAddress;

  final String? userAgent;

  final String expiresAt;

  final String? impersonatedBy;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthSessionInsert copyWith({
    SqlValue<String>? id,
    String? userId,
    String? token,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    String? expiresAt,
    SqlValue<String?>? impersonatedBy,
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
      impersonatedBy: impersonatedBy == null || !impersonatedBy.isPresent
          ? this.impersonatedBy
          : impersonatedBy.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'userId': userId,
    'token': token,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'expiresAt': expiresAt,
    'impersonatedBy': impersonatedBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'userId': userId,
    'token': token,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'expiresAt': expiresAt,
    'impersonatedBy': impersonatedBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionInsert(id: $id, userId: $userId, token: $token, ipAddress: $ipAddress, userAgent: $userAgent, expiresAt: $expiresAt, impersonatedBy: $impersonatedBy, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthSessionUpdate implements JsonEncodable {
  const DartEdgeAuthSessionUpdate({
    this.id = const SqlValue.absent(),
    this.userId = const SqlValue.absent(),
    this.token = const SqlValue.absent(),
    this.ipAddress = const SqlValue.absent(),
    this.userAgent = const SqlValue.absent(),
    this.expiresAt = const SqlValue.absent(),
    this.impersonatedBy = const SqlValue.absent(),
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
    userId: json.containsKey('userId')
        ? SqlValue<String>((json['userId'] as String))
        : const SqlValue.absent(),
    token: json.containsKey('token')
        ? SqlValue<String>((json['token'] as String))
        : const SqlValue.absent(),
    ipAddress: json.containsKey('ipAddress')
        ? SqlValue<String?>(
            json['ipAddress'] == null ? null : (json['ipAddress'] as String),
          )
        : const SqlValue.absent(),
    userAgent: json.containsKey('userAgent')
        ? SqlValue<String?>(
            json['userAgent'] == null ? null : (json['userAgent'] as String),
          )
        : const SqlValue.absent(),
    expiresAt: json.containsKey('expiresAt')
        ? SqlValue<String>((json['expiresAt'] as String))
        : const SqlValue.absent(),
    impersonatedBy: json.containsKey('impersonatedBy')
        ? SqlValue<String?>(
            json['impersonatedBy'] == null
                ? null
                : (json['impersonatedBy'] as String),
          )
        : const SqlValue.absent(),
    createdAt: json.containsKey('createdAt')
        ? SqlValue<String>((json['createdAt'] as String))
        : const SqlValue.absent(),
    updatedAt: json.containsKey('updatedAt')
        ? SqlValue<String>((json['updatedAt'] as String))
        : const SqlValue.absent(),
  );

  static const schemaId = 'DartEdgeAuthSessionUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'token': JsonSchema.string(),
      'ipAddress': JsonSchema.string(nullable: true),
      'userAgent': JsonSchema.string(nullable: true),
      'expiresAt': JsonSchema.string(),
      'impersonatedBy': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(),
      'updatedAt': JsonSchema.string(),
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

  final SqlValue<String?> impersonatedBy;

  final SqlValue<String> createdAt;

  final SqlValue<String> updatedAt;

  DartEdgeAuthSessionUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String>? userId,
    SqlValue<String>? token,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    SqlValue<String>? expiresAt,
    SqlValue<String?>? impersonatedBy,
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
      impersonatedBy: impersonatedBy ?? this.impersonatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (userId.isPresent) 'userId': userId.value,
    if (token.isPresent) 'token': token.value,
    if (ipAddress.isPresent) 'ipAddress': ipAddress.value,
    if (userAgent.isPresent) 'userAgent': userAgent.value,
    if (expiresAt.isPresent) 'expiresAt': expiresAt.value,
    if (impersonatedBy.isPresent) 'impersonatedBy': impersonatedBy.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (userId.isPresent) 'userId': userId.value,
    if (token.isPresent) 'token': token.value,
    if (ipAddress.isPresent) 'ipAddress': ipAddress.value,
    if (userAgent.isPresent) 'userAgent': userAgent.value,
    if (expiresAt.isPresent) 'expiresAt': expiresAt.value,
    if (impersonatedBy.isPresent) 'impersonatedBy': impersonatedBy.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionUpdate(id: $id, userId: $userId, token: $token, ipAddress: $ipAddress, userAgent: $userAgent, expiresAt: $expiresAt, impersonatedBy: $impersonatedBy, createdAt: $createdAt, updatedAt: $updatedAt)';
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
    name: 'userId',
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
    name: 'ipAddress',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final userAgent = SqlColumn<String>(
    table: table,
    name: 'userAgent',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final expiresAt = SqlColumn<String>(
    table: table,
    name: 'expiresAt',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final impersonatedBy = SqlColumn<String>(
    table: table,
    name: 'impersonatedBy',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final createdAt = SqlColumn<String>(
    table: table,
    name: 'createdAt',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final updatedAt = SqlColumn<String>(
    table: table,
    name: 'updatedAt',
    nullable: false,
    databaseType: 'TEXT',
  );

  @override
  String get name => 'session';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'TEXT').asObjectColumn,
    column<String>(
      'userId',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'token',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'ipAddress',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'userAgent',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'expiresAt',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'impersonatedBy',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'createdAt',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'updatedAt',
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
      column<String>('userId', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get token =>
      column<String>('token', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get ipAddress =>
      column<String>('ipAddress', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get userAgent =>
      column<String>('userAgent', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get expiresAt =>
      column<String>('expiresAt', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get impersonatedBy =>
      column<String>('impersonatedBy', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get createdAt =>
      column<String>('createdAt', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get updatedAt =>
      column<String>('updatedAt', nullable: false, databaseType: 'TEXT');
}

final class DartEdgeAuthUserRow implements JsonEncodable {
  const DartEdgeAuthUserRow({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.image,
    required this.role,
    required this.banned,
    required this.banReason,
    required this.banExpires,
    required this.phoneNumber,
    required this.phoneNumberVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthUserRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthUserRow(
        id: row.read<String>('${prefix}id'),
        name: row.read<String>('${prefix}name'),
        email: row.read<String>('${prefix}email'),
        emailVerified: row.read<bool>('${prefix}emailVerified'),
        image: row.readNullable<String>('${prefix}image'),
        role: row.readNullable<String>('${prefix}role'),
        banned: row.readNullable<bool>('${prefix}banned'),
        banReason: row.readNullable<String>('${prefix}banReason'),
        banExpires: row.readNullable<String>('${prefix}banExpires'),
        phoneNumber: row.readNullable<String>('${prefix}phoneNumber'),
        phoneNumberVerified: row.readNullable<bool>(
          '${prefix}phoneNumberVerified',
        ),
        createdAt: row.read<String>('${prefix}createdAt'),
        updatedAt: row.read<String>('${prefix}updatedAt'),
      );

  factory DartEdgeAuthUserRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeAuthUserRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeAuthUserRow.decode(Object? value) =>
      DartEdgeAuthUserRow.fromJson(readJsonObject(value));

  factory DartEdgeAuthUserRow.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthUserRow(
        id: (json['id'] as String),
        name: (json['name'] as String),
        email: (json['email'] as String),
        emailVerified: (json['emailVerified'] as bool),
        image: json['image'] == null ? null : (json['image'] as String),
        role: json['role'] == null ? null : (json['role'] as String),
        banned: json['banned'] == null ? null : (json['banned'] as bool),
        banReason: json['banReason'] == null
            ? null
            : (json['banReason'] as String),
        banExpires: json['banExpires'] == null
            ? null
            : (json['banExpires'] as String),
        phoneNumber: json['phoneNumber'] == null
            ? null
            : (json['phoneNumber'] as String),
        phoneNumberVerified: json['phoneNumberVerified'] == null
            ? null
            : (json['phoneNumberVerified'] as bool),
        createdAt: (json['createdAt'] as String),
        updatedAt: (json['updatedAt'] as String),
      );

  static const schemaId = 'DartEdgeAuthUserRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
      'emailVerified': JsonSchema.boolean(),
      'image': JsonSchema.string(nullable: true),
      'role': JsonSchema.string(nullable: true),
      'banned': JsonSchema.boolean(nullable: true),
      'banReason': JsonSchema.string(nullable: true),
      'banExpires': JsonSchema.string(nullable: true),
      'phoneNumber': JsonSchema.string(nullable: true),
      'phoneNumberVerified': JsonSchema.boolean(nullable: true),
      'createdAt': JsonSchema.string(),
      'updatedAt': JsonSchema.string(),
    },
    required: <String>[
      'id',
      'name',
      'email',
      'emailVerified',
      'image',
      'role',
      'banned',
      'banReason',
      'banExpires',
      'phoneNumber',
      'phoneNumberVerified',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final String id;

  final String name;

  final String email;

  final bool emailVerified;

  final String? image;

  final String? role;

  final bool? banned;

  final String? banReason;

  final String? banExpires;

  final String? phoneNumber;

  final bool? phoneNumberVerified;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthUserRow copyWith({
    String? id,
    String? name,
    String? email,
    bool? emailVerified,
    SqlValue<String?>? image,
    SqlValue<String?>? role,
    SqlValue<bool?>? banned,
    SqlValue<String?>? banReason,
    SqlValue<String?>? banExpires,
    SqlValue<String?>? phoneNumber,
    SqlValue<bool?>? phoneNumberVerified,
    String? createdAt,
    String? updatedAt,
  }) {
    return DartEdgeAuthUserRow(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image == null || !image.isPresent ? this.image : image.value,
      role: role == null || !role.isPresent ? this.role : role.value,
      banned: banned == null || !banned.isPresent ? this.banned : banned.value,
      banReason: banReason == null || !banReason.isPresent
          ? this.banReason
          : banReason.value,
      banExpires: banExpires == null || !banExpires.isPresent
          ? this.banExpires
          : banExpires.value,
      phoneNumber: phoneNumber == null || !phoneNumber.isPresent
          ? this.phoneNumber
          : phoneNumber.value,
      phoneNumberVerified:
          phoneNumberVerified == null || !phoneNumberVerified.isPresent
          ? this.phoneNumberVerified
          : phoneNumberVerified.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires,
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires,
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserRow(id: $id, name: $name, email: $email, emailVerified: $emailVerified, image: $image, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, phoneNumber: $phoneNumber, phoneNumberVerified: $phoneNumberVerified, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthUserInsert implements JsonEncodable {
  const DartEdgeAuthUserInsert({
    this.id = const SqlValue.absent(),
    required this.name,
    required this.email,
    this.emailVerified = const SqlValue.absent(),
    required this.image,
    required this.role,
    required this.banned,
    required this.banReason,
    required this.banExpires,
    required this.phoneNumber,
    required this.phoneNumberVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthUserInsert.decode(Object? value) =>
      DartEdgeAuthUserInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthUserInsert.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthUserInsert(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        name: (json['name'] as String),
        email: (json['email'] as String),
        emailVerified: json.containsKey('emailVerified')
            ? SqlValue<bool>((json['emailVerified'] as bool))
            : const SqlValue.absent(),
        image: json['image'] == null ? null : (json['image'] as String),
        role: json['role'] == null ? null : (json['role'] as String),
        banned: json['banned'] == null ? null : (json['banned'] as bool),
        banReason: json['banReason'] == null
            ? null
            : (json['banReason'] as String),
        banExpires: json['banExpires'] == null
            ? null
            : (json['banExpires'] as String),
        phoneNumber: json['phoneNumber'] == null
            ? null
            : (json['phoneNumber'] as String),
        phoneNumberVerified: json['phoneNumberVerified'] == null
            ? null
            : (json['phoneNumberVerified'] as bool),
        createdAt: (json['createdAt'] as String),
        updatedAt: (json['updatedAt'] as String),
      );

  static const schemaId = 'DartEdgeAuthUserInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
      'emailVerified': JsonSchema.boolean(),
      'image': JsonSchema.string(nullable: true),
      'role': JsonSchema.string(nullable: true),
      'banned': JsonSchema.boolean(nullable: true),
      'banReason': JsonSchema.string(nullable: true),
      'banExpires': JsonSchema.string(nullable: true),
      'phoneNumber': JsonSchema.string(nullable: true),
      'phoneNumberVerified': JsonSchema.boolean(nullable: true),
      'createdAt': JsonSchema.string(),
      'updatedAt': JsonSchema.string(),
    },
    required: <String>[
      'name',
      'email',
      'image',
      'role',
      'banned',
      'banReason',
      'banExpires',
      'phoneNumber',
      'phoneNumberVerified',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String name;

  final String email;

  final SqlValue<bool> emailVerified;

  final String? image;

  final String? role;

  final bool? banned;

  final String? banReason;

  final String? banExpires;

  final String? phoneNumber;

  final bool? phoneNumberVerified;

  final String createdAt;

  final String updatedAt;

  DartEdgeAuthUserInsert copyWith({
    SqlValue<String>? id,
    String? name,
    String? email,
    SqlValue<bool>? emailVerified,
    SqlValue<String?>? image,
    SqlValue<String?>? role,
    SqlValue<bool?>? banned,
    SqlValue<String?>? banReason,
    SqlValue<String?>? banExpires,
    SqlValue<String?>? phoneNumber,
    SqlValue<bool?>? phoneNumberVerified,
    String? createdAt,
    String? updatedAt,
  }) {
    return DartEdgeAuthUserInsert(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image == null || !image.isPresent ? this.image : image.value,
      role: role == null || !role.isPresent ? this.role : role.value,
      banned: banned == null || !banned.isPresent ? this.banned : banned.value,
      banReason: banReason == null || !banReason.isPresent
          ? this.banReason
          : banReason.value,
      banExpires: banExpires == null || !banExpires.isPresent
          ? this.banExpires
          : banExpires.value,
      phoneNumber: phoneNumber == null || !phoneNumber.isPresent
          ? this.phoneNumber
          : phoneNumber.value,
      phoneNumberVerified:
          phoneNumberVerified == null || !phoneNumberVerified.isPresent
          ? this.phoneNumberVerified
          : phoneNumberVerified.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
    if (emailVerified.isPresent) 'emailVerified': emailVerified.value,
    'image': image,
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires,
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
    if (emailVerified.isPresent) 'emailVerified': emailVerified.value,
    'image': image,
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires,
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserInsert(id: $id, name: $name, email: $email, emailVerified: $emailVerified, image: $image, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, phoneNumber: $phoneNumber, phoneNumberVerified: $phoneNumberVerified, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthUserUpdate implements JsonEncodable {
  const DartEdgeAuthUserUpdate({
    this.id = const SqlValue.absent(),
    this.name = const SqlValue.absent(),
    this.email = const SqlValue.absent(),
    this.emailVerified = const SqlValue.absent(),
    this.image = const SqlValue.absent(),
    this.role = const SqlValue.absent(),
    this.banned = const SqlValue.absent(),
    this.banReason = const SqlValue.absent(),
    this.banExpires = const SqlValue.absent(),
    this.phoneNumber = const SqlValue.absent(),
    this.phoneNumberVerified = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.updatedAt = const SqlValue.absent(),
  });

  factory DartEdgeAuthUserUpdate.decode(Object? value) =>
      DartEdgeAuthUserUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthUserUpdate.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthUserUpdate(
    id: json.containsKey('id')
        ? SqlValue<String>((json['id'] as String))
        : const SqlValue.absent(),
    name: json.containsKey('name')
        ? SqlValue<String>((json['name'] as String))
        : const SqlValue.absent(),
    email: json.containsKey('email')
        ? SqlValue<String>((json['email'] as String))
        : const SqlValue.absent(),
    emailVerified: json.containsKey('emailVerified')
        ? SqlValue<bool>((json['emailVerified'] as bool))
        : const SqlValue.absent(),
    image: json.containsKey('image')
        ? SqlValue<String?>(
            json['image'] == null ? null : (json['image'] as String),
          )
        : const SqlValue.absent(),
    role: json.containsKey('role')
        ? SqlValue<String?>(
            json['role'] == null ? null : (json['role'] as String),
          )
        : const SqlValue.absent(),
    banned: json.containsKey('banned')
        ? SqlValue<bool?>(
            json['banned'] == null ? null : (json['banned'] as bool),
          )
        : const SqlValue.absent(),
    banReason: json.containsKey('banReason')
        ? SqlValue<String?>(
            json['banReason'] == null ? null : (json['banReason'] as String),
          )
        : const SqlValue.absent(),
    banExpires: json.containsKey('banExpires')
        ? SqlValue<String?>(
            json['banExpires'] == null ? null : (json['banExpires'] as String),
          )
        : const SqlValue.absent(),
    phoneNumber: json.containsKey('phoneNumber')
        ? SqlValue<String?>(
            json['phoneNumber'] == null
                ? null
                : (json['phoneNumber'] as String),
          )
        : const SqlValue.absent(),
    phoneNumberVerified: json.containsKey('phoneNumberVerified')
        ? SqlValue<bool?>(
            json['phoneNumberVerified'] == null
                ? null
                : (json['phoneNumberVerified'] as bool),
          )
        : const SqlValue.absent(),
    createdAt: json.containsKey('createdAt')
        ? SqlValue<String>((json['createdAt'] as String))
        : const SqlValue.absent(),
    updatedAt: json.containsKey('updatedAt')
        ? SqlValue<String>((json['updatedAt'] as String))
        : const SqlValue.absent(),
  );

  static const schemaId = 'DartEdgeAuthUserUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
      'emailVerified': JsonSchema.boolean(),
      'image': JsonSchema.string(nullable: true),
      'role': JsonSchema.string(nullable: true),
      'banned': JsonSchema.boolean(nullable: true),
      'banReason': JsonSchema.string(nullable: true),
      'banExpires': JsonSchema.string(nullable: true),
      'phoneNumber': JsonSchema.string(nullable: true),
      'phoneNumberVerified': JsonSchema.boolean(nullable: true),
      'createdAt': JsonSchema.string(),
      'updatedAt': JsonSchema.string(),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<String> name;

  final SqlValue<String> email;

  final SqlValue<bool> emailVerified;

  final SqlValue<String?> image;

  final SqlValue<String?> role;

  final SqlValue<bool?> banned;

  final SqlValue<String?> banReason;

  final SqlValue<String?> banExpires;

  final SqlValue<String?> phoneNumber;

  final SqlValue<bool?> phoneNumberVerified;

  final SqlValue<String> createdAt;

  final SqlValue<String> updatedAt;

  DartEdgeAuthUserUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String>? name,
    SqlValue<String>? email,
    SqlValue<bool>? emailVerified,
    SqlValue<String?>? image,
    SqlValue<String?>? role,
    SqlValue<bool?>? banned,
    SqlValue<String?>? banReason,
    SqlValue<String?>? banExpires,
    SqlValue<String?>? phoneNumber,
    SqlValue<bool?>? phoneNumberVerified,
    SqlValue<String>? createdAt,
    SqlValue<String>? updatedAt,
  }) {
    return DartEdgeAuthUserUpdate(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image ?? this.image,
      role: role ?? this.role,
      banned: banned ?? this.banned,
      banReason: banReason ?? this.banReason,
      banExpires: banExpires ?? this.banExpires,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneNumberVerified: phoneNumberVerified ?? this.phoneNumberVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (emailVerified.isPresent) 'emailVerified': emailVerified.value,
    if (image.isPresent) 'image': image.value,
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    if (banReason.isPresent) 'banReason': banReason.value,
    if (banExpires.isPresent) 'banExpires': banExpires.value,
    if (phoneNumber.isPresent) 'phoneNumber': phoneNumber.value,
    if (phoneNumberVerified.isPresent)
      'phoneNumberVerified': phoneNumberVerified.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (emailVerified.isPresent) 'emailVerified': emailVerified.value,
    if (image.isPresent) 'image': image.value,
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    if (banReason.isPresent) 'banReason': banReason.value,
    if (banExpires.isPresent) 'banExpires': banExpires.value,
    if (phoneNumber.isPresent) 'phoneNumber': phoneNumber.value,
    if (phoneNumberVerified.isPresent)
      'phoneNumberVerified': phoneNumberVerified.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserUpdate(id: $id, name: $name, email: $email, emailVerified: $emailVerified, image: $image, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, phoneNumber: $phoneNumber, phoneNumberVerified: $phoneNumberVerified, createdAt: $createdAt, updatedAt: $updatedAt)';
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
    nullable: false,
    databaseType: 'TEXT',
  );

  static final email = SqlColumn<String>(
    table: table,
    name: 'email',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final emailVerified = SqlColumn<bool>(
    table: table,
    name: 'emailVerified',
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
    nullable: true,
    databaseType: 'TEXT',
  );

  static final banned = SqlColumn<bool>(
    table: table,
    name: 'banned',
    nullable: true,
    databaseType: 'BOOLEAN',
  );

  static final banReason = SqlColumn<String>(
    table: table,
    name: 'banReason',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final banExpires = SqlColumn<String>(
    table: table,
    name: 'banExpires',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final phoneNumber = SqlColumn<String>(
    table: table,
    name: 'phoneNumber',
    nullable: true,
    databaseType: 'TEXT',
  );

  static final phoneNumberVerified = SqlColumn<bool>(
    table: table,
    name: 'phoneNumberVerified',
    nullable: true,
    databaseType: 'BOOLEAN',
  );

  static final createdAt = SqlColumn<String>(
    table: table,
    name: 'createdAt',
    nullable: false,
    databaseType: 'TEXT',
  );

  static final updatedAt = SqlColumn<String>(
    table: table,
    name: 'updatedAt',
    nullable: false,
    databaseType: 'TEXT',
  );

  @override
  String get name => 'user';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'TEXT').asObjectColumn,
    column<String>(
      'name',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'email',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<bool>(
      'emailVerified',
      nullable: false,
      databaseType: 'BOOLEAN',
    ).asObjectColumn,
    column<String>(
      'image',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>('role', nullable: true, databaseType: 'TEXT').asObjectColumn,
    column<bool>(
      'banned',
      nullable: true,
      databaseType: 'BOOLEAN',
    ).asObjectColumn,
    column<String>(
      'banReason',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'banExpires',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'phoneNumber',
      nullable: true,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<bool>(
      'phoneNumberVerified',
      nullable: true,
      databaseType: 'BOOLEAN',
    ).asObjectColumn,
    column<String>(
      'createdAt',
      nullable: false,
      databaseType: 'TEXT',
    ).asObjectColumn,
    column<String>(
      'updatedAt',
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
      column<String>('name', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get email =>
      column<String>('email', nullable: false, databaseType: 'TEXT');

  SqlColumn<bool> get emailVerified =>
      column<bool>('emailVerified', nullable: false, databaseType: 'BOOLEAN');

  SqlColumn<String> get image =>
      column<String>('image', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get role =>
      column<String>('role', nullable: true, databaseType: 'TEXT');

  SqlColumn<bool> get banned =>
      column<bool>('banned', nullable: true, databaseType: 'BOOLEAN');

  SqlColumn<String> get banReason =>
      column<String>('banReason', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get banExpires =>
      column<String>('banExpires', nullable: true, databaseType: 'TEXT');

  SqlColumn<String> get phoneNumber =>
      column<String>('phoneNumber', nullable: true, databaseType: 'TEXT');

  SqlColumn<bool> get phoneNumberVerified => column<bool>(
    'phoneNumberVerified',
    nullable: true,
    databaseType: 'BOOLEAN',
  );

  SqlColumn<String> get createdAt =>
      column<String>('createdAt', nullable: false, databaseType: 'TEXT');

  SqlColumn<String> get updatedAt =>
      column<String>('updatedAt', nullable: false, databaseType: 'TEXT');
}
