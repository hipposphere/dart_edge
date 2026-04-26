import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

final class PeopleRow implements JsonEncodable {
  const PeopleRow({required this.id, required this.name, required this.email});

  factory PeopleRow.fromSqlRow(SqlRow row, {String prefix = ''}) => PeopleRow(
    id: row.readNullable<int>('${prefix}id'),
    name: row.read<String>('${prefix}name'),
    email: row.read<String>('${prefix}email'),
  );

  factory PeopleRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => PeopleRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory PeopleRow.fromJson(Map<String, Object?> json) => PeopleRow(
    id: json['id'] == null ? null : (json['id'] as num).toInt(),
    name: (json['name'] as String),
    email: (json['email'] as String),
  );

  static const schemaRef = JsonSchemaRef<PeopleRow>('PeopleRow');

  static const jsonSchema = JsonSchema.object(
    ref: schemaRef,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(nullable: true),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
    },
    required: <String>['id', 'name', 'email'],
    additionalProperties: false,
  );

  final int? id;

  final String name;

  final String email;

  PeopleRow copyWith({SqlValue<int?>? id, String? name, String? email}) {
    return PeopleRow(
      id: id == null || !id.isPresent ? this.id : id.value,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
  };

  @override
  String toString() => 'PeopleRow(id: $id, name: $name, email: $email)';
}

final class PeopleInsert implements JsonEncodable {
  const PeopleInsert({
    this.id = const SqlValue.absent(),
    required this.name,
    required this.email,
  });

  factory PeopleInsert.fromJson(Map<String, Object?> json) => PeopleInsert(
    id: json.containsKey('id')
        ? SqlValue<int?>(
            json['id'] == null ? null : (json['id'] as num).toInt(),
          )
        : const SqlValue.absent(),
    name: (json['name'] as String),
    email: (json['email'] as String),
  );

  static const schemaRef = JsonSchemaRef<PeopleInsert>('PeopleInsert');

  static const jsonSchema = JsonSchema.object(
    ref: schemaRef,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(nullable: true),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
    },
    required: <String>['name', 'email'],
    additionalProperties: false,
  );

  final SqlValue<int?> id;

  final String name;

  final String email;

  PeopleInsert copyWith({SqlValue<int?>? id, String? name, String? email}) {
    return PeopleInsert(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
  };

  @override
  String toString() => 'PeopleInsert(id: $id, name: $name, email: $email)';
}

final class PeopleUpdate implements JsonEncodable {
  const PeopleUpdate({
    this.id = const SqlValue.absent(),
    this.name = const SqlValue.absent(),
    this.email = const SqlValue.absent(),
  });

  factory PeopleUpdate.fromJson(Map<String, Object?> json) => PeopleUpdate(
    id: json.containsKey('id')
        ? SqlValue<int?>(
            json['id'] == null ? null : (json['id'] as num).toInt(),
          )
        : const SqlValue.absent(),
    name: json.containsKey('name')
        ? SqlValue<String>((json['name'] as String))
        : const SqlValue.absent(),
    email: json.containsKey('email')
        ? SqlValue<String>((json['email'] as String))
        : const SqlValue.absent(),
  );

  static const schemaRef = JsonSchemaRef<PeopleUpdate>('PeopleUpdate');

  static const jsonSchema = JsonSchema.object(
    ref: schemaRef,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(nullable: true),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<int?> id;

  final SqlValue<String> name;

  final SqlValue<String> email;

  PeopleUpdate copyWith({
    SqlValue<int?>? id,
    SqlValue<String>? name,
    SqlValue<String>? email,
  }) {
    return PeopleUpdate(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
  };

  @override
  String toString() => 'PeopleUpdate(id: $id, name: $name, email: $email)';
}

final class PeopleTable
    extends SqlTable<PeopleRow, PeopleInsert, PeopleUpdate> {
  const PeopleTable._();

  static const table = PeopleTable._();

  static final id = SqlColumn<int>(table: table, name: 'id', nullable: true);

  static final nameColumn = SqlColumn<String>(
    table: table,
    name: 'name',
    nullable: false,
  );

  static final email = SqlColumn<String>(
    table: table,
    name: 'email',
    nullable: false,
  );

  @override
  String get name => 'people';

  @override
  String? get schema => null;

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    id.asObjectColumn,
    nameColumn.asObjectColumn,
    email.asObjectColumn,
  ];

  @override
  PeopleRow mapRow(SqlRow row, {String prefix = ''}) =>
      PeopleRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(PeopleInsert value) => value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(PeopleUpdate value) => value.toColumns();
}
