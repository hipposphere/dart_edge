import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:json_schema/json_schema.dart';

final class DartEdgeAuthVerificationRow implements JsonEncodable {
  const DartEdgeAuthVerificationRow({
    required this.id,
    required this.identifier,
    required this.value,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthVerificationRow.fromSqlRow(
    SqlRow row, {
    String prefix = '',
  }) => DartEdgeAuthVerificationRow(
    id: row.read<String>('${prefix}id'),
    identifier: row.read<String>('${prefix}identifier'),
    value: row.read<String>('${prefix}value'),
    expiresAt: switch (row.read<Object?>('${prefix}expiresAt')) {
      final DateTime value => value,
      final String value => DateTime.parse(value),
      final value => value as DateTime,
    },
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
  );

  factory DartEdgeAuthVerificationRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeAuthVerificationRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeAuthVerificationRow.decode(Object? value) =>
      DartEdgeAuthVerificationRow.fromJson(readJsonObject(value));

  factory DartEdgeAuthVerificationRow.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthVerificationRow(
        id: (json['id'] as String),
        identifier: (json['identifier'] as String),
        value: (json['value'] as String),
        expiresAt: DateTime.parse((json['expiresAt'] as String)),
        createdAt: DateTime.parse((json['createdAt'] as String)),
        updatedAt: DateTime.parse((json['updatedAt'] as String)),
      );

  static const schemaId = 'DartEdgeAuthVerificationRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'identifier': JsonSchema.string(),
      'value': JsonSchema.string(),
      'expiresAt': JsonSchema.string(format: 'date-time'),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
    },
    required: <String>[
      'id',
      'identifier',
      'value',
      'expiresAt',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final String id;

  final String identifier;

  final String value;

  final DateTime expiresAt;

  final DateTime createdAt;

  final DateTime updatedAt;

  DartEdgeAuthVerificationRow copyWith({
    String? id,
    String? identifier,
    String? value,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DartEdgeAuthVerificationRow(
      id: id ?? this.id,
      identifier: identifier ?? this.identifier,
      value: value ?? this.value,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'identifier': identifier,
    'value': value,
    'expiresAt': expiresAt,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'identifier': identifier,
    'value': value,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'DartEdgeAuthVerificationRow(id: $id, identifier: $identifier, value: $value, expiresAt: $expiresAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthVerificationInsert implements JsonEncodable {
  const DartEdgeAuthVerificationInsert({
    this.id = const SqlValue.absent(),
    required this.identifier,
    required this.value,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthVerificationInsert.decode(Object? value) =>
      DartEdgeAuthVerificationInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthVerificationInsert.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthVerificationInsert(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        identifier: (json['identifier'] as String),
        value: (json['value'] as String),
        expiresAt: DateTime.parse((json['expiresAt'] as String)),
        createdAt: DateTime.parse((json['createdAt'] as String)),
        updatedAt: DateTime.parse((json['updatedAt'] as String)),
      );

  static const schemaId = 'DartEdgeAuthVerificationInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'identifier': JsonSchema.string(),
      'value': JsonSchema.string(),
      'expiresAt': JsonSchema.string(format: 'date-time'),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
    },
    required: <String>[
      'identifier',
      'value',
      'expiresAt',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String identifier;

  final String value;

  final DateTime expiresAt;

  final DateTime createdAt;

  final DateTime updatedAt;

  DartEdgeAuthVerificationInsert copyWith({
    SqlValue<String>? id,
    String? identifier,
    String? value,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DartEdgeAuthVerificationInsert(
      id: id ?? this.id,
      identifier: identifier ?? this.identifier,
      value: value ?? this.value,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'identifier': identifier,
    'value': value,
    'expiresAt': expiresAt,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'identifier': identifier,
    'value': value,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'DartEdgeAuthVerificationInsert(id: $id, identifier: $identifier, value: $value, expiresAt: $expiresAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthVerificationUpdate implements JsonEncodable {
  const DartEdgeAuthVerificationUpdate({
    this.id = const SqlValue.absent(),
    this.identifier = const SqlValue.absent(),
    this.value = const SqlValue.absent(),
    this.expiresAt = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.updatedAt = const SqlValue.absent(),
  });

  factory DartEdgeAuthVerificationUpdate.decode(Object? value) =>
      DartEdgeAuthVerificationUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthVerificationUpdate.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthVerificationUpdate(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        identifier: json.containsKey('identifier')
            ? SqlValue<String>((json['identifier'] as String))
            : const SqlValue.absent(),
        value: json.containsKey('value')
            ? SqlValue<String>((json['value'] as String))
            : const SqlValue.absent(),
        expiresAt: json.containsKey('expiresAt')
            ? SqlValue<DateTime>(DateTime.parse((json['expiresAt'] as String)))
            : const SqlValue.absent(),
        createdAt: json.containsKey('createdAt')
            ? SqlValue<DateTime>(DateTime.parse((json['createdAt'] as String)))
            : const SqlValue.absent(),
        updatedAt: json.containsKey('updatedAt')
            ? SqlValue<DateTime>(DateTime.parse((json['updatedAt'] as String)))
            : const SqlValue.absent(),
      );

  static const schemaId = 'DartEdgeAuthVerificationUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'identifier': JsonSchema.string(),
      'value': JsonSchema.string(),
      'expiresAt': JsonSchema.string(format: 'date-time'),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<String> identifier;

  final SqlValue<String> value;

  final SqlValue<DateTime> expiresAt;

  final SqlValue<DateTime> createdAt;

  final SqlValue<DateTime> updatedAt;

  DartEdgeAuthVerificationUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String>? identifier,
    SqlValue<String>? value,
    SqlValue<DateTime>? expiresAt,
    SqlValue<DateTime>? createdAt,
    SqlValue<DateTime>? updatedAt,
  }) {
    return DartEdgeAuthVerificationUpdate(
      id: id ?? this.id,
      identifier: identifier ?? this.identifier,
      value: value ?? this.value,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (identifier.isPresent) 'identifier': identifier.value,
    if (value.isPresent) 'value': value.value,
    if (expiresAt.isPresent) 'expiresAt': expiresAt.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (identifier.isPresent) 'identifier': identifier.value,
    if (value.isPresent) 'value': value.value,
    if (expiresAt.isPresent) 'expiresAt': expiresAt.value?.toIso8601String(),
    if (createdAt.isPresent) 'createdAt': createdAt.value?.toIso8601String(),
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value?.toIso8601String(),
  };

  @override
  String toString() =>
      'DartEdgeAuthVerificationUpdate(id: $id, identifier: $identifier, value: $value, expiresAt: $expiresAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthVerificationsTable
    extends
        SqlTable<
          DartEdgeAuthVerificationRow,
          DartEdgeAuthVerificationInsert,
          DartEdgeAuthVerificationUpdate
        > {
  const DartEdgeAuthVerificationsTable._() : schema = null;

  const DartEdgeAuthVerificationsTable.withSchema(this.schema);

  @override
  final String? schema;

  static const table = DartEdgeAuthVerificationsTable._();

  static final id = SqlColumn<String>(
    table: table,
    name: 'id',
    nullable: false,
    databaseType: 'text',
  );

  static final identifier = SqlColumn<String>(
    table: table,
    name: 'identifier',
    nullable: false,
    databaseType: 'text',
  );

  static final value = SqlColumn<String>(
    table: table,
    name: 'value',
    nullable: false,
    databaseType: 'text',
  );

  static final expiresAt = SqlColumn<DateTime>(
    table: table,
    name: 'expiresAt',
    nullable: false,
    databaseType: 'timestamptz',
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

  @override
  String get name => 'verification';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'text').asObjectColumn,
    column<String>(
      'identifier',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'value',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<DateTime>(
      'expiresAt',
      nullable: false,
      databaseType: 'timestamptz',
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
  ];

  @override
  DartEdgeAuthVerificationRow mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthVerificationRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(DartEdgeAuthVerificationInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(DartEdgeAuthVerificationUpdate value) =>
      value.toColumns();
}

extension DartEdgeAuthVerificationsTableColumns
    on DartEdgeAuthVerificationsTable {
  SqlColumn<String> get id =>
      column<String>('id', nullable: false, databaseType: 'text');

  SqlColumn<String> get identifier =>
      column<String>('identifier', nullable: false, databaseType: 'text');

  SqlColumn<String> get value =>
      column<String>('value', nullable: false, databaseType: 'text');

  SqlColumn<DateTime> get expiresAt => column<DateTime>(
    'expiresAt',
    nullable: false,
    databaseType: 'timestamptz',
  );

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
}
