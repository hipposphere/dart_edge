import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:json_schema/json_schema.dart';
import 'people.g.dart';

extension type const PublicNoteId(int value) {
  static const manifest = SqlKeyManifestEntry(
    dartType: 'PublicNoteId',
    baseDartType: 'int',
    schema: 'public',
    table: 'notes',
    column: 'id',
  );
}

final class PublicNotesRow implements JsonEncodable {
  const PublicNotesRow({
    required this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    required this.createdAt,
  });

  factory PublicNotesRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      PublicNotesRow(
        id: PublicNoteId(row.read<int>('${prefix}id')),
        title: row.read<String>('${prefix}title'),
        body: row.read<String>('${prefix}body'),
        ownerId: PublicPeopleId(row.read<int>('${prefix}owner_id')),
        createdAt: row.read<String>('${prefix}created_at'),
      );

  factory PublicNotesRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => PublicNotesRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory PublicNotesRow.decode(Object? value) =>
      PublicNotesRow.fromJson(readJsonObject(value));

  factory PublicNotesRow.fromJson(Map<String, Object?> json) => PublicNotesRow(
    id: PublicNoteId((json['id'] as num).toInt()),
    title: (json['title'] as String),
    body: (json['body'] as String),
    ownerId: PublicPeopleId((json['owner_id'] as num).toInt()),
    createdAt: (json['created_at'] as String),
  );

  static const schemaId = 'PublicNotesRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(),
      'title': JsonSchema.string(),
      'body': JsonSchema.string(),
      'owner_id': JsonSchema.integer(),
      'created_at': JsonSchema.string(),
    },
    required: <String>['id', 'title', 'body', 'owner_id', 'created_at'],
    additionalProperties: false,
  );

  final PublicNoteId id;

  final String title;

  final String body;

  final PublicPeopleId ownerId;

  final String createdAt;

  PublicNotesRow copyWith({
    PublicNoteId? id,
    String? title,
    String? body,
    PublicPeopleId? ownerId,
    String? createdAt,
  }) {
    return PublicNotesRow(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id.value,
    'title': title,
    'body': body,
    'owner_id': ownerId.value,
    'created_at': createdAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id.value,
    'title': title,
    'body': body,
    'owner_id': ownerId.value,
    'created_at': createdAt,
  };

  @override
  String toString() =>
      'PublicNotesRow(id: $id, title: $title, body: $body, ownerId: $ownerId, createdAt: $createdAt)';
}

final class PublicNotesInsert implements JsonEncodable {
  const PublicNotesInsert({
    this.id = const SqlValue.absent(),
    required this.title,
    required this.body,
    required this.ownerId,
    this.createdAt = const SqlValue.absent(),
  });

  factory PublicNotesInsert.decode(Object? value) =>
      PublicNotesInsert.fromJson(readJsonObject(value));

  factory PublicNotesInsert.fromJson(Map<String, Object?> json) =>
      PublicNotesInsert(
        id: json.containsKey('id')
            ? SqlValue<PublicNoteId>(PublicNoteId((json['id'] as num).toInt()))
            : const SqlValue.absent(),
        title: (json['title'] as String),
        body: (json['body'] as String),
        ownerId: PublicPeopleId((json['owner_id'] as num).toInt()),
        createdAt: json.containsKey('created_at')
            ? SqlValue<String>((json['created_at'] as String))
            : const SqlValue.absent(),
      );

  static const schemaId = 'PublicNotesInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(),
      'title': JsonSchema.string(),
      'body': JsonSchema.string(),
      'owner_id': JsonSchema.integer(),
      'created_at': JsonSchema.string(),
    },
    required: <String>['title', 'body', 'owner_id'],
    additionalProperties: false,
  );

  final SqlValue<PublicNoteId> id;

  final String title;

  final String body;

  final PublicPeopleId ownerId;

  final SqlValue<String> createdAt;

  PublicNotesInsert copyWith({
    SqlValue<PublicNoteId>? id,
    String? title,
    String? body,
    PublicPeopleId? ownerId,
    SqlValue<String>? createdAt,
  }) {
    return PublicNotesInsert(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    'title': title,
    'body': body,
    'owner_id': ownerId.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    'title': title,
    'body': body,
    'owner_id': ownerId.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  String toString() =>
      'PublicNotesInsert(id: $id, title: $title, body: $body, ownerId: $ownerId, createdAt: $createdAt)';
}

final class PublicNotesUpdate implements JsonEncodable {
  const PublicNotesUpdate({
    this.id = const SqlValue.absent(),
    this.title = const SqlValue.absent(),
    this.body = const SqlValue.absent(),
    this.ownerId = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
  });

  factory PublicNotesUpdate.decode(Object? value) =>
      PublicNotesUpdate.fromJson(readJsonObject(value));

  factory PublicNotesUpdate.fromJson(Map<String, Object?> json) =>
      PublicNotesUpdate(
        id: json.containsKey('id')
            ? SqlValue<PublicNoteId>(PublicNoteId((json['id'] as num).toInt()))
            : const SqlValue.absent(),
        title: json.containsKey('title')
            ? SqlValue<String>((json['title'] as String))
            : const SqlValue.absent(),
        body: json.containsKey('body')
            ? SqlValue<String>((json['body'] as String))
            : const SqlValue.absent(),
        ownerId: json.containsKey('owner_id')
            ? SqlValue<PublicPeopleId>(
                PublicPeopleId((json['owner_id'] as num).toInt()),
              )
            : const SqlValue.absent(),
        createdAt: json.containsKey('created_at')
            ? SqlValue<String>((json['created_at'] as String))
            : const SqlValue.absent(),
      );

  static const schemaId = 'PublicNotesUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(),
      'title': JsonSchema.string(),
      'body': JsonSchema.string(),
      'owner_id': JsonSchema.integer(),
      'created_at': JsonSchema.string(),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<PublicNoteId> id;

  final SqlValue<String> title;

  final SqlValue<String> body;

  final SqlValue<PublicPeopleId> ownerId;

  final SqlValue<String> createdAt;

  PublicNotesUpdate copyWith({
    SqlValue<PublicNoteId>? id,
    SqlValue<String>? title,
    SqlValue<String>? body,
    SqlValue<PublicPeopleId>? ownerId,
    SqlValue<String>? createdAt,
  }) {
    return PublicNotesUpdate(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    if (title.isPresent) 'title': title.value,
    if (body.isPresent) 'body': body.value,
    if (ownerId.isPresent) 'owner_id': ownerId.value?.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    if (title.isPresent) 'title': title.value,
    if (body.isPresent) 'body': body.value,
    if (ownerId.isPresent) 'owner_id': ownerId.value?.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  String toString() =>
      'PublicNotesUpdate(id: $id, title: $title, body: $body, ownerId: $ownerId, createdAt: $createdAt)';
}

final class PublicNotesTable
    extends SqlTable<PublicNotesRow, PublicNotesInsert, PublicNotesUpdate> {
  const PublicNotesTable._() : schema = 'public';

  const PublicNotesTable.withSchema(this.schema);

  @override
  final String? schema;

  static const table = PublicNotesTable._();

  static const id = SqlColumn<PublicNoteId>(
    table: table,
    name: 'id',
    nullable: false,
    databaseType: 'int4',
  );

  static const title = SqlColumn<String>(
    table: table,
    name: 'title',
    nullable: false,
    databaseType: 'text',
  );

  static const body = SqlColumn<String>(
    table: table,
    name: 'body',
    nullable: false,
    databaseType: 'text',
  );

  static const ownerId = SqlColumn<PublicPeopleId>(
    table: table,
    name: 'owner_id',
    nullable: false,
    databaseType: 'int4',
  );

  static const createdAt = SqlColumn<String>(
    table: table,
    name: 'created_at',
    nullable: false,
    databaseType: 'text',
  );

  @override
  String get name => 'notes';

  @override
  List<SqlColumnBase> get columns => <SqlColumnBase>[
    id,
    title,
    body,
    ownerId,
    createdAt,
  ];

  @override
  PublicNotesRow mapRow(SqlRow row, {String prefix = ''}) =>
      PublicNotesRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(PublicNotesInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(PublicNotesUpdate value) =>
      value.toColumns();
}
