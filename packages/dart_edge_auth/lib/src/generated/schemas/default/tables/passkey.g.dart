import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:json_schema/json_schema.dart';

final class DartEdgeAuthPasskeyRow implements JsonEncodable {
  const DartEdgeAuthPasskeyRow({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.userId,
    required this.credentialID,
    required this.counter,
    required this.deviceType,
    required this.backedUp,
    required this.transports,
    required this.createdAt,
    required this.aaguid,
  });

  factory DartEdgeAuthPasskeyRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthPasskeyRow(
        id: row.read<String>('${prefix}id'),
        name: row.readNullable<String>('${prefix}name'),
        publicKey: row.read<String>('${prefix}publicKey'),
        userId: row.read<String>('${prefix}userId'),
        credentialID: row.read<String>('${prefix}credentialID'),
        counter: row.read<int>('${prefix}counter'),
        deviceType: row.read<String>('${prefix}deviceType'),
        backedUp: row.read<bool>('${prefix}backedUp'),
        transports: row.readNullable<String>('${prefix}transports'),
        createdAt: switch (row.readNullable<Object?>('${prefix}createdAt')) {
          null => null,
          final DateTime value => value,
          final String value => DateTime.parse(value),
          final value => value as DateTime,
        },
        aaguid: row.readNullable<String>('${prefix}aaguid'),
      );

  factory DartEdgeAuthPasskeyRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeAuthPasskeyRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeAuthPasskeyRow.decode(Object? value) =>
      DartEdgeAuthPasskeyRow.fromJson(readJsonObject(value));

  factory DartEdgeAuthPasskeyRow.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthPasskeyRow(
        id: (json['id'] as String),
        name: json['name'] == null ? null : (json['name'] as String),
        publicKey: (json['publicKey'] as String),
        userId: (json['userId'] as String),
        credentialID: (json['credentialID'] as String),
        counter: (json['counter'] as num).toInt(),
        deviceType: (json['deviceType'] as String),
        backedUp: (json['backedUp'] as bool),
        transports: json['transports'] == null
            ? null
            : (json['transports'] as String),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse((json['createdAt'] as String)),
        aaguid: json['aaguid'] == null ? null : (json['aaguid'] as String),
      );

  static const schemaId = 'DartEdgeAuthPasskeyRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(nullable: true),
      'publicKey': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'credentialID': JsonSchema.string(),
      'counter': JsonSchema.integer(),
      'deviceType': JsonSchema.string(),
      'backedUp': JsonSchema.boolean(),
      'transports': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(nullable: true, format: 'date-time'),
      'aaguid': JsonSchema.string(nullable: true),
    },
    required: <String>[
      'id',
      'name',
      'publicKey',
      'userId',
      'credentialID',
      'counter',
      'deviceType',
      'backedUp',
      'transports',
      'createdAt',
      'aaguid',
    ],
    additionalProperties: false,
  );

  final String id;

  final String? name;

  final String publicKey;

  final String userId;

  final String credentialID;

  final int counter;

  final String deviceType;

  final bool backedUp;

  final String? transports;

  final DateTime? createdAt;

  final String? aaguid;

  DartEdgeAuthPasskeyRow copyWith({
    String? id,
    SqlValue<String?>? name,
    String? publicKey,
    String? userId,
    String? credentialID,
    int? counter,
    String? deviceType,
    bool? backedUp,
    SqlValue<String?>? transports,
    SqlValue<DateTime?>? createdAt,
    SqlValue<String?>? aaguid,
  }) {
    return DartEdgeAuthPasskeyRow(
      id: id ?? this.id,
      name: name == null || !name.isPresent ? this.name : name.value,
      publicKey: publicKey ?? this.publicKey,
      userId: userId ?? this.userId,
      credentialID: credentialID ?? this.credentialID,
      counter: counter ?? this.counter,
      deviceType: deviceType ?? this.deviceType,
      backedUp: backedUp ?? this.backedUp,
      transports: transports == null || !transports.isPresent
          ? this.transports
          : transports.value,
      createdAt: createdAt == null || !createdAt.isPresent
          ? this.createdAt
          : createdAt.value,
      aaguid: aaguid == null || !aaguid.isPresent ? this.aaguid : aaguid.value,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'name': name,
    'publicKey': publicKey,
    'userId': userId,
    'credentialID': credentialID,
    'counter': counter,
    'deviceType': deviceType,
    'backedUp': backedUp,
    'transports': transports,
    'createdAt': createdAt,
    'aaguid': aaguid,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'publicKey': publicKey,
    'userId': userId,
    'credentialID': credentialID,
    'counter': counter,
    'deviceType': deviceType,
    'backedUp': backedUp,
    'transports': transports,
    'createdAt': createdAt?.toIso8601String(),
    'aaguid': aaguid,
  };

  @override
  String toString() =>
      'DartEdgeAuthPasskeyRow(id: $id, name: $name, publicKey: $publicKey, userId: $userId, credentialID: $credentialID, counter: $counter, deviceType: $deviceType, backedUp: $backedUp, transports: $transports, createdAt: $createdAt, aaguid: $aaguid)';
}

final class DartEdgeAuthPasskeyInsert implements JsonEncodable {
  const DartEdgeAuthPasskeyInsert({
    this.id = const SqlValue.absent(),
    required this.name,
    required this.publicKey,
    required this.userId,
    required this.credentialID,
    required this.counter,
    required this.deviceType,
    required this.backedUp,
    required this.transports,
    required this.createdAt,
    required this.aaguid,
  });

  factory DartEdgeAuthPasskeyInsert.decode(Object? value) =>
      DartEdgeAuthPasskeyInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthPasskeyInsert.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthPasskeyInsert(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        name: json['name'] == null ? null : (json['name'] as String),
        publicKey: (json['publicKey'] as String),
        userId: (json['userId'] as String),
        credentialID: (json['credentialID'] as String),
        counter: (json['counter'] as num).toInt(),
        deviceType: (json['deviceType'] as String),
        backedUp: (json['backedUp'] as bool),
        transports: json['transports'] == null
            ? null
            : (json['transports'] as String),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse((json['createdAt'] as String)),
        aaguid: json['aaguid'] == null ? null : (json['aaguid'] as String),
      );

  static const schemaId = 'DartEdgeAuthPasskeyInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(nullable: true),
      'publicKey': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'credentialID': JsonSchema.string(),
      'counter': JsonSchema.integer(),
      'deviceType': JsonSchema.string(),
      'backedUp': JsonSchema.boolean(),
      'transports': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(nullable: true, format: 'date-time'),
      'aaguid': JsonSchema.string(nullable: true),
    },
    required: <String>[
      'name',
      'publicKey',
      'userId',
      'credentialID',
      'counter',
      'deviceType',
      'backedUp',
      'transports',
      'createdAt',
      'aaguid',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String? name;

  final String publicKey;

  final String userId;

  final String credentialID;

  final int counter;

  final String deviceType;

  final bool backedUp;

  final String? transports;

  final DateTime? createdAt;

  final String? aaguid;

  DartEdgeAuthPasskeyInsert copyWith({
    SqlValue<String>? id,
    SqlValue<String?>? name,
    String? publicKey,
    String? userId,
    String? credentialID,
    int? counter,
    String? deviceType,
    bool? backedUp,
    SqlValue<String?>? transports,
    SqlValue<DateTime?>? createdAt,
    SqlValue<String?>? aaguid,
  }) {
    return DartEdgeAuthPasskeyInsert(
      id: id ?? this.id,
      name: name == null || !name.isPresent ? this.name : name.value,
      publicKey: publicKey ?? this.publicKey,
      userId: userId ?? this.userId,
      credentialID: credentialID ?? this.credentialID,
      counter: counter ?? this.counter,
      deviceType: deviceType ?? this.deviceType,
      backedUp: backedUp ?? this.backedUp,
      transports: transports == null || !transports.isPresent
          ? this.transports
          : transports.value,
      createdAt: createdAt == null || !createdAt.isPresent
          ? this.createdAt
          : createdAt.value,
      aaguid: aaguid == null || !aaguid.isPresent ? this.aaguid : aaguid.value,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'publicKey': publicKey,
    'userId': userId,
    'credentialID': credentialID,
    'counter': counter,
    'deviceType': deviceType,
    'backedUp': backedUp,
    'transports': transports,
    'createdAt': createdAt,
    'aaguid': aaguid,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'publicKey': publicKey,
    'userId': userId,
    'credentialID': credentialID,
    'counter': counter,
    'deviceType': deviceType,
    'backedUp': backedUp,
    'transports': transports,
    'createdAt': createdAt?.toIso8601String(),
    'aaguid': aaguid,
  };

  @override
  String toString() =>
      'DartEdgeAuthPasskeyInsert(id: $id, name: $name, publicKey: $publicKey, userId: $userId, credentialID: $credentialID, counter: $counter, deviceType: $deviceType, backedUp: $backedUp, transports: $transports, createdAt: $createdAt, aaguid: $aaguid)';
}

final class DartEdgeAuthPasskeyUpdate implements JsonEncodable {
  const DartEdgeAuthPasskeyUpdate({
    this.id = const SqlValue.absent(),
    this.name = const SqlValue.absent(),
    this.publicKey = const SqlValue.absent(),
    this.userId = const SqlValue.absent(),
    this.credentialID = const SqlValue.absent(),
    this.counter = const SqlValue.absent(),
    this.deviceType = const SqlValue.absent(),
    this.backedUp = const SqlValue.absent(),
    this.transports = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.aaguid = const SqlValue.absent(),
  });

  factory DartEdgeAuthPasskeyUpdate.decode(Object? value) =>
      DartEdgeAuthPasskeyUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthPasskeyUpdate.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthPasskeyUpdate(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        name: json.containsKey('name')
            ? SqlValue<String?>(
                json['name'] == null ? null : (json['name'] as String),
              )
            : const SqlValue.absent(),
        publicKey: json.containsKey('publicKey')
            ? SqlValue<String>((json['publicKey'] as String))
            : const SqlValue.absent(),
        userId: json.containsKey('userId')
            ? SqlValue<String>((json['userId'] as String))
            : const SqlValue.absent(),
        credentialID: json.containsKey('credentialID')
            ? SqlValue<String>((json['credentialID'] as String))
            : const SqlValue.absent(),
        counter: json.containsKey('counter')
            ? SqlValue<int>((json['counter'] as num).toInt())
            : const SqlValue.absent(),
        deviceType: json.containsKey('deviceType')
            ? SqlValue<String>((json['deviceType'] as String))
            : const SqlValue.absent(),
        backedUp: json.containsKey('backedUp')
            ? SqlValue<bool>((json['backedUp'] as bool))
            : const SqlValue.absent(),
        transports: json.containsKey('transports')
            ? SqlValue<String?>(
                json['transports'] == null
                    ? null
                    : (json['transports'] as String),
              )
            : const SqlValue.absent(),
        createdAt: json.containsKey('createdAt')
            ? SqlValue<DateTime?>(
                json['createdAt'] == null
                    ? null
                    : DateTime.parse((json['createdAt'] as String)),
              )
            : const SqlValue.absent(),
        aaguid: json.containsKey('aaguid')
            ? SqlValue<String?>(
                json['aaguid'] == null ? null : (json['aaguid'] as String),
              )
            : const SqlValue.absent(),
      );

  static const schemaId = 'DartEdgeAuthPasskeyUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'name': JsonSchema.string(nullable: true),
      'publicKey': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'credentialID': JsonSchema.string(),
      'counter': JsonSchema.integer(),
      'deviceType': JsonSchema.string(),
      'backedUp': JsonSchema.boolean(),
      'transports': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(nullable: true, format: 'date-time'),
      'aaguid': JsonSchema.string(nullable: true),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<String?> name;

  final SqlValue<String> publicKey;

  final SqlValue<String> userId;

  final SqlValue<String> credentialID;

  final SqlValue<int> counter;

  final SqlValue<String> deviceType;

  final SqlValue<bool> backedUp;

  final SqlValue<String?> transports;

  final SqlValue<DateTime?> createdAt;

  final SqlValue<String?> aaguid;

  DartEdgeAuthPasskeyUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String?>? name,
    SqlValue<String>? publicKey,
    SqlValue<String>? userId,
    SqlValue<String>? credentialID,
    SqlValue<int>? counter,
    SqlValue<String>? deviceType,
    SqlValue<bool>? backedUp,
    SqlValue<String?>? transports,
    SqlValue<DateTime?>? createdAt,
    SqlValue<String?>? aaguid,
  }) {
    return DartEdgeAuthPasskeyUpdate(
      id: id ?? this.id,
      name: name ?? this.name,
      publicKey: publicKey ?? this.publicKey,
      userId: userId ?? this.userId,
      credentialID: credentialID ?? this.credentialID,
      counter: counter ?? this.counter,
      deviceType: deviceType ?? this.deviceType,
      backedUp: backedUp ?? this.backedUp,
      transports: transports ?? this.transports,
      createdAt: createdAt ?? this.createdAt,
      aaguid: aaguid ?? this.aaguid,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (publicKey.isPresent) 'publicKey': publicKey.value,
    if (userId.isPresent) 'userId': userId.value,
    if (credentialID.isPresent) 'credentialID': credentialID.value,
    if (counter.isPresent) 'counter': counter.value,
    if (deviceType.isPresent) 'deviceType': deviceType.value,
    if (backedUp.isPresent) 'backedUp': backedUp.value,
    if (transports.isPresent) 'transports': transports.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (aaguid.isPresent) 'aaguid': aaguid.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (publicKey.isPresent) 'publicKey': publicKey.value,
    if (userId.isPresent) 'userId': userId.value,
    if (credentialID.isPresent) 'credentialID': credentialID.value,
    if (counter.isPresent) 'counter': counter.value,
    if (deviceType.isPresent) 'deviceType': deviceType.value,
    if (backedUp.isPresent) 'backedUp': backedUp.value,
    if (transports.isPresent) 'transports': transports.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value?.toIso8601String(),
    if (aaguid.isPresent) 'aaguid': aaguid.value,
  };

  @override
  String toString() =>
      'DartEdgeAuthPasskeyUpdate(id: $id, name: $name, publicKey: $publicKey, userId: $userId, credentialID: $credentialID, counter: $counter, deviceType: $deviceType, backedUp: $backedUp, transports: $transports, createdAt: $createdAt, aaguid: $aaguid)';
}

final class DartEdgeAuthPasskeysTable
    extends
        SqlTable<
          DartEdgeAuthPasskeyRow,
          DartEdgeAuthPasskeyInsert,
          DartEdgeAuthPasskeyUpdate
        > {
  const DartEdgeAuthPasskeysTable._() : schema = null;

  const DartEdgeAuthPasskeysTable.withSchema(this.schema);

  @override
  final String? schema;

  static const table = DartEdgeAuthPasskeysTable._();

  static final id = SqlColumn<String>(
    table: table,
    name: 'id',
    nullable: false,
    databaseType: 'text',
  );

  static final nameColumn = SqlColumn<String>(
    table: table,
    name: 'name',
    nullable: true,
    databaseType: 'text',
  );

  static final publicKey = SqlColumn<String>(
    table: table,
    name: 'publicKey',
    nullable: false,
    databaseType: 'text',
  );

  static final userId = SqlColumn<String>(
    table: table,
    name: 'userId',
    nullable: false,
    databaseType: 'text',
  );

  static final credentialID = SqlColumn<String>(
    table: table,
    name: 'credentialID',
    nullable: false,
    databaseType: 'text',
  );

  static final counter = SqlColumn<int>(
    table: table,
    name: 'counter',
    nullable: false,
    databaseType: 'int4',
  );

  static final deviceType = SqlColumn<String>(
    table: table,
    name: 'deviceType',
    nullable: false,
    databaseType: 'text',
  );

  static final backedUp = SqlColumn<bool>(
    table: table,
    name: 'backedUp',
    nullable: false,
    databaseType: 'bool',
  );

  static final transports = SqlColumn<String>(
    table: table,
    name: 'transports',
    nullable: true,
    databaseType: 'text',
  );

  static final createdAt = SqlColumn<DateTime>(
    table: table,
    name: 'createdAt',
    nullable: true,
    databaseType: 'timestamptz',
  );

  static final aaguid = SqlColumn<String>(
    table: table,
    name: 'aaguid',
    nullable: true,
    databaseType: 'text',
  );

  @override
  String get name => 'passkey';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'text').asObjectColumn,
    column<String>('name', nullable: true, databaseType: 'text').asObjectColumn,
    column<String>(
      'publicKey',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'userId',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'credentialID',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<int>(
      'counter',
      nullable: false,
      databaseType: 'int4',
    ).asObjectColumn,
    column<String>(
      'deviceType',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<bool>(
      'backedUp',
      nullable: false,
      databaseType: 'bool',
    ).asObjectColumn,
    column<String>(
      'transports',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<DateTime>(
      'createdAt',
      nullable: true,
      databaseType: 'timestamptz',
    ).asObjectColumn,
    column<String>(
      'aaguid',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
  ];

  @override
  DartEdgeAuthPasskeyRow mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthPasskeyRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(DartEdgeAuthPasskeyInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(DartEdgeAuthPasskeyUpdate value) =>
      value.toColumns();
}

extension DartEdgeAuthPasskeysTableColumns on DartEdgeAuthPasskeysTable {
  SqlColumn<String> get id =>
      column<String>('id', nullable: false, databaseType: 'text');

  SqlColumn<String> get nameColumn =>
      column<String>('name', nullable: true, databaseType: 'text');

  SqlColumn<String> get publicKey =>
      column<String>('publicKey', nullable: false, databaseType: 'text');

  SqlColumn<String> get userId =>
      column<String>('userId', nullable: false, databaseType: 'text');

  SqlColumn<String> get credentialID =>
      column<String>('credentialID', nullable: false, databaseType: 'text');

  SqlColumn<int> get counter =>
      column<int>('counter', nullable: false, databaseType: 'int4');

  SqlColumn<String> get deviceType =>
      column<String>('deviceType', nullable: false, databaseType: 'text');

  SqlColumn<bool> get backedUp =>
      column<bool>('backedUp', nullable: false, databaseType: 'bool');

  SqlColumn<String> get transports =>
      column<String>('transports', nullable: true, databaseType: 'text');

  SqlColumn<DateTime> get createdAt => column<DateTime>(
    'createdAt',
    nullable: true,
    databaseType: 'timestamptz',
  );

  SqlColumn<String> get aaguid =>
      column<String>('aaguid', nullable: true, databaseType: 'text');
}
