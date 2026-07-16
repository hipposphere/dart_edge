import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:json_schema/json_schema.dart';

final class DartEdgeAuthSessionRow implements JsonEncodable {
  const DartEdgeAuthSessionRow({
    required this.id,
    required this.expiresAt,
    required this.token,
    required this.createdAt,
    required this.updatedAt,
    required this.ipAddress,
    required this.userAgent,
    required this.userId,
    required this.impersonatedBy,
  });

  factory DartEdgeAuthSessionRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthSessionRow(
        id: row.read<String>('${prefix}id'),
        expiresAt: switch (row.read<Object?>('${prefix}expiresAt')) {
          final DateTime value => value,
          final String value => DateTime.parse(value),
          final value => value as DateTime,
        },
        token: row.read<String>('${prefix}token'),
        createdAt: switch (row.read<Object?>('${prefix}createdAt')) {
          final DateTime value => value,
          final String value => DateTime.parse(value),
          final value => value as DateTime,
        },
        updatedAt: switch (row.read<Object?>('${prefix}updatedAt')) {
          final DateTime value => value,
          final String value => DateTime.parse(value),
          final value => value as DateTime,
        },
        ipAddress: row.readNullable<String>('${prefix}ipAddress'),
        userAgent: row.readNullable<String>('${prefix}userAgent'),
        userId: row.read<String>('${prefix}userId'),
        impersonatedBy: row.readNullable<String>('${prefix}impersonatedBy'),
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
    expiresAt: DateTime.parse((json['expiresAt'] as String)),
    token: (json['token'] as String),
    createdAt: DateTime.parse((json['createdAt'] as String)),
    updatedAt: DateTime.parse((json['updatedAt'] as String)),
    ipAddress: json['ipAddress'] == null ? null : (json['ipAddress'] as String),
    userAgent: json['userAgent'] == null ? null : (json['userAgent'] as String),
    userId: (json['userId'] as String),
    impersonatedBy: json['impersonatedBy'] == null
        ? null
        : (json['impersonatedBy'] as String),
  );

  static const schemaId = 'DartEdgeAuthSessionRow';

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
    ],
    additionalProperties: false,
  );

  final String id;

  final DateTime expiresAt;

  final String token;

  final DateTime createdAt;

  final DateTime updatedAt;

  final String? ipAddress;

  final String? userAgent;

  final String userId;

  final String? impersonatedBy;

  DartEdgeAuthSessionRow copyWith({
    String? id,
    DateTime? expiresAt,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    String? userId,
    SqlValue<String?>? impersonatedBy,
  }) {
    return DartEdgeAuthSessionRow(
      id: id ?? this.id,
      expiresAt: expiresAt ?? this.expiresAt,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ipAddress: ipAddress == null || !ipAddress.isPresent
          ? this.ipAddress
          : ipAddress.value,
      userAgent: userAgent == null || !userAgent.isPresent
          ? this.userAgent
          : userAgent.value,
      userId: userId ?? this.userId,
      impersonatedBy: impersonatedBy == null || !impersonatedBy.isPresent
          ? this.impersonatedBy
          : impersonatedBy.value,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'expiresAt': expiresAt,
    'token': token,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'userId': userId,
    'impersonatedBy': impersonatedBy,
  };

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
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionRow(id: $id, expiresAt: $expiresAt, token: $token, createdAt: $createdAt, updatedAt: $updatedAt, ipAddress: $ipAddress, userAgent: $userAgent, userId: $userId, impersonatedBy: $impersonatedBy)';
}

final class DartEdgeAuthSessionInsert implements JsonEncodable {
  const DartEdgeAuthSessionInsert({
    this.id = const SqlValue.absent(),
    required this.expiresAt,
    required this.token,
    required this.createdAt,
    required this.updatedAt,
    required this.ipAddress,
    required this.userAgent,
    required this.userId,
    required this.impersonatedBy,
  });

  factory DartEdgeAuthSessionInsert.decode(Object? value) =>
      DartEdgeAuthSessionInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthSessionInsert.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthSessionInsert(
    id: json.containsKey('id')
        ? SqlValue<String>((json['id'] as String))
        : const SqlValue.absent(),
    expiresAt: DateTime.parse((json['expiresAt'] as String)),
    token: (json['token'] as String),
    createdAt: DateTime.parse((json['createdAt'] as String)),
    updatedAt: DateTime.parse((json['updatedAt'] as String)),
    ipAddress: json['ipAddress'] == null ? null : (json['ipAddress'] as String),
    userAgent: json['userAgent'] == null ? null : (json['userAgent'] as String),
    userId: (json['userId'] as String),
    impersonatedBy: json['impersonatedBy'] == null
        ? null
        : (json['impersonatedBy'] as String),
  );

  static const schemaId = 'DartEdgeAuthSessionInsert';

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
    },
    required: <String>[
      'expiresAt',
      'token',
      'createdAt',
      'updatedAt',
      'ipAddress',
      'userAgent',
      'userId',
      'impersonatedBy',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final DateTime expiresAt;

  final String token;

  final DateTime createdAt;

  final DateTime updatedAt;

  final String? ipAddress;

  final String? userAgent;

  final String userId;

  final String? impersonatedBy;

  DartEdgeAuthSessionInsert copyWith({
    SqlValue<String>? id,
    DateTime? expiresAt,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    String? userId,
    SqlValue<String?>? impersonatedBy,
  }) {
    return DartEdgeAuthSessionInsert(
      id: id ?? this.id,
      expiresAt: expiresAt ?? this.expiresAt,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ipAddress: ipAddress == null || !ipAddress.isPresent
          ? this.ipAddress
          : ipAddress.value,
      userAgent: userAgent == null || !userAgent.isPresent
          ? this.userAgent
          : userAgent.value,
      userId: userId ?? this.userId,
      impersonatedBy: impersonatedBy == null || !impersonatedBy.isPresent
          ? this.impersonatedBy
          : impersonatedBy.value,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'expiresAt': expiresAt,
    'token': token,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'userId': userId,
    'impersonatedBy': impersonatedBy,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'expiresAt': expiresAt.toIso8601String(),
    'token': token,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'ipAddress': ipAddress,
    'userAgent': userAgent,
    'userId': userId,
    'impersonatedBy': impersonatedBy,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionInsert(id: $id, expiresAt: $expiresAt, token: $token, createdAt: $createdAt, updatedAt: $updatedAt, ipAddress: $ipAddress, userAgent: $userAgent, userId: $userId, impersonatedBy: $impersonatedBy)';
}

final class DartEdgeAuthSessionUpdate implements JsonEncodable {
  const DartEdgeAuthSessionUpdate({
    this.id = const SqlValue.absent(),
    this.expiresAt = const SqlValue.absent(),
    this.token = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.updatedAt = const SqlValue.absent(),
    this.ipAddress = const SqlValue.absent(),
    this.userAgent = const SqlValue.absent(),
    this.userId = const SqlValue.absent(),
    this.impersonatedBy = const SqlValue.absent(),
  });

  factory DartEdgeAuthSessionUpdate.decode(Object? value) =>
      DartEdgeAuthSessionUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthSessionUpdate.fromJson(
    Map<String, Object?> json,
  ) => DartEdgeAuthSessionUpdate(
    id: json.containsKey('id')
        ? SqlValue<String>((json['id'] as String))
        : const SqlValue.absent(),
    expiresAt: json.containsKey('expiresAt')
        ? SqlValue<DateTime>(DateTime.parse((json['expiresAt'] as String)))
        : const SqlValue.absent(),
    token: json.containsKey('token')
        ? SqlValue<String>((json['token'] as String))
        : const SqlValue.absent(),
    createdAt: json.containsKey('createdAt')
        ? SqlValue<DateTime>(DateTime.parse((json['createdAt'] as String)))
        : const SqlValue.absent(),
    updatedAt: json.containsKey('updatedAt')
        ? SqlValue<DateTime>(DateTime.parse((json['updatedAt'] as String)))
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
    userId: json.containsKey('userId')
        ? SqlValue<String>((json['userId'] as String))
        : const SqlValue.absent(),
    impersonatedBy: json.containsKey('impersonatedBy')
        ? SqlValue<String?>(
            json['impersonatedBy'] == null
                ? null
                : (json['impersonatedBy'] as String),
          )
        : const SqlValue.absent(),
  );

  static const schemaId = 'DartEdgeAuthSessionUpdate';

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
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<DateTime> expiresAt;

  final SqlValue<String> token;

  final SqlValue<DateTime> createdAt;

  final SqlValue<DateTime> updatedAt;

  final SqlValue<String?> ipAddress;

  final SqlValue<String?> userAgent;

  final SqlValue<String> userId;

  final SqlValue<String?> impersonatedBy;

  DartEdgeAuthSessionUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<DateTime>? expiresAt,
    SqlValue<String>? token,
    SqlValue<DateTime>? createdAt,
    SqlValue<DateTime>? updatedAt,
    SqlValue<String?>? ipAddress,
    SqlValue<String?>? userAgent,
    SqlValue<String>? userId,
    SqlValue<String?>? impersonatedBy,
  }) {
    return DartEdgeAuthSessionUpdate(
      id: id ?? this.id,
      expiresAt: expiresAt ?? this.expiresAt,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      userId: userId ?? this.userId,
      impersonatedBy: impersonatedBy ?? this.impersonatedBy,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (expiresAt.isPresent) 'expiresAt': expiresAt.value,
    if (token.isPresent) 'token': token.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
    if (ipAddress.isPresent) 'ipAddress': ipAddress.value,
    if (userAgent.isPresent) 'userAgent': userAgent.value,
    if (userId.isPresent) 'userId': userId.value,
    if (impersonatedBy.isPresent) 'impersonatedBy': impersonatedBy.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (expiresAt.isPresent) 'expiresAt': expiresAt.value?.toIso8601String(),
    if (token.isPresent) 'token': token.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value?.toIso8601String(),
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value?.toIso8601String(),
    if (ipAddress.isPresent) 'ipAddress': ipAddress.value,
    if (userAgent.isPresent) 'userAgent': userAgent.value,
    if (userId.isPresent) 'userId': userId.value,
    if (impersonatedBy.isPresent) 'impersonatedBy': impersonatedBy.value,
  };

  @override
  String toString() =>
      'DartEdgeAuthSessionUpdate(id: $id, expiresAt: $expiresAt, token: $token, createdAt: $createdAt, updatedAt: $updatedAt, ipAddress: $ipAddress, userAgent: $userAgent, userId: $userId, impersonatedBy: $impersonatedBy)';
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
    databaseType: 'text',
  );

  static final expiresAt = SqlColumn<DateTime>(
    table: table,
    name: 'expiresAt',
    nullable: false,
    databaseType: 'timestamptz',
  );

  static final token = SqlColumn<String>(
    table: table,
    name: 'token',
    nullable: false,
    databaseType: 'text',
  );

  static final createdAt = SqlColumn<DateTime>(
    table: table,
    name: 'createdAt',
    nullable: false,
    databaseType: 'timestamptz',
  );

  static final updatedAt = SqlColumn<DateTime>(
    table: table,
    name: 'updatedAt',
    nullable: false,
    databaseType: 'timestamptz',
  );

  static final ipAddress = SqlColumn<String>(
    table: table,
    name: 'ipAddress',
    nullable: true,
    databaseType: 'text',
  );

  static final userAgent = SqlColumn<String>(
    table: table,
    name: 'userAgent',
    nullable: true,
    databaseType: 'text',
  );

  static final userId = SqlColumn<String>(
    table: table,
    name: 'userId',
    nullable: false,
    databaseType: 'text',
  );

  static final impersonatedBy = SqlColumn<String>(
    table: table,
    name: 'impersonatedBy',
    nullable: true,
    databaseType: 'text',
  );

  @override
  String get name => 'session';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'text').asObjectColumn,
    column<DateTime>(
      'expiresAt',
      nullable: false,
      databaseType: 'timestamptz',
    ).asObjectColumn,
    column<String>(
      'token',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<DateTime>(
      'createdAt',
      nullable: false,
      databaseType: 'timestamptz',
    ).asObjectColumn,
    column<DateTime>(
      'updatedAt',
      nullable: false,
      databaseType: 'timestamptz',
    ).asObjectColumn,
    column<String>(
      'ipAddress',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'userAgent',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'userId',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'impersonatedBy',
      nullable: true,
      databaseType: 'text',
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
      column<String>('id', nullable: false, databaseType: 'text');

  SqlColumn<DateTime> get expiresAt => column<DateTime>(
    'expiresAt',
    nullable: false,
    databaseType: 'timestamptz',
  );

  SqlColumn<String> get token =>
      column<String>('token', nullable: false, databaseType: 'text');

  SqlColumn<DateTime> get createdAt => column<DateTime>(
    'createdAt',
    nullable: false,
    databaseType: 'timestamptz',
  );

  SqlColumn<DateTime> get updatedAt => column<DateTime>(
    'updatedAt',
    nullable: false,
    databaseType: 'timestamptz',
  );

  SqlColumn<String> get ipAddress =>
      column<String>('ipAddress', nullable: true, databaseType: 'text');

  SqlColumn<String> get userAgent =>
      column<String>('userAgent', nullable: true, databaseType: 'text');

  SqlColumn<String> get userId =>
      column<String>('userId', nullable: false, databaseType: 'text');

  SqlColumn<String> get impersonatedBy =>
      column<String>('impersonatedBy', nullable: true, databaseType: 'text');
}
