import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

final class NotesRow implements JsonEncodable {
  const NotesRow({
    required this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    required this.createdAt,
  });

  factory NotesRow.fromSqlRow(SqlRow row, {String prefix = ''}) => NotesRow(
    id: row.read<int>('${prefix}id'),
    title: row.read<String>('${prefix}title'),
    body: row.read<String>('${prefix}body'),
    ownerId: row.read<int>('${prefix}owner_id'),
    createdAt: row.read<String>('${prefix}created_at'),
  );

  factory NotesRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => NotesRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory NotesRow.fromJson(Map<String, Object?> json) => NotesRow(
    id: (json['id'] as num).toInt(),
    title: (json['title'] as String),
    body: (json['body'] as String),
    ownerId: (json['owner_id'] as num).toInt(),
    createdAt: (json['created_at'] as String),
  );

  static const schemaId = 'NotesRow';

  static const schemaRef = JsonSchema.ref(schemaId);

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

  final int id;

  final String title;

  final String body;

  final int ownerId;

  final String createdAt;

  NotesRow copyWith({
    int? id,
    String? title,
    String? body,
    int? ownerId,
    String? createdAt,
  }) {
    return NotesRow(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'title': title,
    'body': body,
    'owner_id': ownerId,
    'created_at': createdAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'body': body,
    'owner_id': ownerId,
    'created_at': createdAt,
  };

  @override
  String toString() =>
      'NotesRow(id: $id, title: $title, body: $body, ownerId: $ownerId, createdAt: $createdAt)';
}

final class NotesInsert implements JsonEncodable {
  const NotesInsert({
    this.id = const SqlValue.absent(),
    required this.title,
    required this.body,
    required this.ownerId,
    this.createdAt = const SqlValue.absent(),
  });

  factory NotesInsert.fromJson(Map<String, Object?> json) => NotesInsert(
    id: json.containsKey('id')
        ? SqlValue<int>((json['id'] as num).toInt())
        : const SqlValue.absent(),
    title: (json['title'] as String),
    body: (json['body'] as String),
    ownerId: (json['owner_id'] as num).toInt(),
    createdAt: json.containsKey('created_at')
        ? SqlValue<String>((json['created_at'] as String))
        : const SqlValue.absent(),
  );

  static const schemaId = 'NotesInsert';

  static const schemaRef = JsonSchema.ref(schemaId);

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

  final SqlValue<int> id;

  final String title;

  final String body;

  final int ownerId;

  final SqlValue<String> createdAt;

  NotesInsert copyWith({
    SqlValue<int>? id,
    String? title,
    String? body,
    int? ownerId,
    SqlValue<String>? createdAt,
  }) {
    return NotesInsert(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'title': title,
    'body': body,
    'owner_id': ownerId,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'title': title,
    'body': body,
    'owner_id': ownerId,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  String toString() =>
      'NotesInsert(id: $id, title: $title, body: $body, ownerId: $ownerId, createdAt: $createdAt)';
}

final class NotesUpdate implements JsonEncodable {
  const NotesUpdate({
    this.id = const SqlValue.absent(),
    this.title = const SqlValue.absent(),
    this.body = const SqlValue.absent(),
    this.ownerId = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
  });

  factory NotesUpdate.fromJson(Map<String, Object?> json) => NotesUpdate(
    id: json.containsKey('id')
        ? SqlValue<int>((json['id'] as num).toInt())
        : const SqlValue.absent(),
    title: json.containsKey('title')
        ? SqlValue<String>((json['title'] as String))
        : const SqlValue.absent(),
    body: json.containsKey('body')
        ? SqlValue<String>((json['body'] as String))
        : const SqlValue.absent(),
    ownerId: json.containsKey('owner_id')
        ? SqlValue<int>((json['owner_id'] as num).toInt())
        : const SqlValue.absent(),
    createdAt: json.containsKey('created_at')
        ? SqlValue<String>((json['created_at'] as String))
        : const SqlValue.absent(),
  );

  static const schemaId = 'NotesUpdate';

  static const schemaRef = JsonSchema.ref(schemaId);

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

  final SqlValue<int> id;

  final SqlValue<String> title;

  final SqlValue<String> body;

  final SqlValue<int> ownerId;

  final SqlValue<String> createdAt;

  NotesUpdate copyWith({
    SqlValue<int>? id,
    SqlValue<String>? title,
    SqlValue<String>? body,
    SqlValue<int>? ownerId,
    SqlValue<String>? createdAt,
  }) {
    return NotesUpdate(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (title.isPresent) 'title': title.value,
    if (body.isPresent) 'body': body.value,
    if (ownerId.isPresent) 'owner_id': ownerId.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (title.isPresent) 'title': title.value,
    if (body.isPresent) 'body': body.value,
    if (ownerId.isPresent) 'owner_id': ownerId.value,
    if (createdAt.isPresent) 'created_at': createdAt.value,
  };

  @override
  String toString() =>
      'NotesUpdate(id: $id, title: $title, body: $body, ownerId: $ownerId, createdAt: $createdAt)';
}

final class NotesTable extends SqlTable<NotesRow, NotesInsert, NotesUpdate> {
  const NotesTable._();

  static const table = NotesTable._();

  static final id = SqlColumn<int>(table: table, name: 'id', nullable: false);

  static final title = SqlColumn<String>(
    table: table,
    name: 'title',
    nullable: false,
  );

  static final body = SqlColumn<String>(
    table: table,
    name: 'body',
    nullable: false,
  );

  static final ownerId = SqlColumn<int>(
    table: table,
    name: 'owner_id',
    nullable: false,
  );

  static final createdAt = SqlColumn<String>(
    table: table,
    name: 'created_at',
    nullable: false,
  );

  @override
  String get name => 'notes';

  @override
  String? get schema => 'public';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    id.asObjectColumn,
    title.asObjectColumn,
    body.asObjectColumn,
    ownerId.asObjectColumn,
    createdAt.asObjectColumn,
  ];

  @override
  NotesRow mapRow(SqlRow row, {String prefix = ''}) =>
      NotesRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(NotesInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(NotesUpdate value) => value.toColumns();
}
