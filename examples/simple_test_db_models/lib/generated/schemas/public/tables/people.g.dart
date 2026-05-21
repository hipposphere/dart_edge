import 'package:dart_edge_core/dart_edge_core.dart';

extension type const PublicPeopleId(int value) {}

extension type const PublicPeopleRole._(String value) {
  static const admin = PublicPeopleRole._('admin');
  static const member = PublicPeopleRole._('member');

  static const values = <PublicPeopleRole>[admin, member];

  static PublicPeopleRole fromDatabase(Object? value) {
    final text = value as String;
    return switch (text) {
      'admin' => admin,
      'member' => member,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Unknown PublicPeopleRole database value.',
      ),
    };
  }
}

final class PublicPeopleRow implements JsonEncodable {
  const PublicPeopleRow({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory PublicPeopleRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      PublicPeopleRow(
        id: PublicPeopleId(row.read<int>('${prefix}id')),
        name: row.read<String>('${prefix}name'),
        email: row.read<String>('${prefix}email'),
        role: PublicPeopleRole.fromDatabase(row.read<String>('${prefix}role')),
      );

  factory PublicPeopleRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => PublicPeopleRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory PublicPeopleRow.decode(Object? value) =>
      PublicPeopleRow.fromJson(readJsonObject(value));

  factory PublicPeopleRow.fromJson(Map<String, Object?> json) =>
      PublicPeopleRow(
        id: PublicPeopleId((json['id'] as num).toInt()),
        name: (json['name'] as String),
        email: (json['email'] as String),
        role: PublicPeopleRole.fromDatabase((json['role'] as String)),
      );

  static const schemaId = 'PublicPeopleRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
      'role': JsonSchema.string(enumValues: <String>['admin', 'member']),
    },
    required: <String>['id', 'name', 'email', 'role'],
    additionalProperties: false,
  );

  final PublicPeopleId id;

  final String name;

  final String email;

  final PublicPeopleRole role;

  PublicPeopleRow copyWith({
    PublicPeopleId? id,
    String? name,
    String? email,
    PublicPeopleRole? role,
  }) {
    return PublicPeopleRow(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id.value,
    'name': name,
    'email': email,
    'role': role.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id.value,
    'name': name,
    'email': email,
    'role': role.value,
  };

  @override
  String toString() =>
      'PublicPeopleRow(id: $id, name: $name, email: $email, role: $role)';
}

final class PublicPeopleInsert implements JsonEncodable {
  const PublicPeopleInsert({
    this.id = const SqlValue.absent(),
    required this.name,
    required this.email,
    this.role = const SqlValue.absent(),
  });

  factory PublicPeopleInsert.decode(Object? value) =>
      PublicPeopleInsert.fromJson(readJsonObject(value));

  factory PublicPeopleInsert.fromJson(Map<String, Object?> json) =>
      PublicPeopleInsert(
        id: json.containsKey('id')
            ? SqlValue<PublicPeopleId>(
                PublicPeopleId((json['id'] as num).toInt()),
              )
            : const SqlValue.absent(),
        name: (json['name'] as String),
        email: (json['email'] as String),
        role: json.containsKey('role')
            ? SqlValue<PublicPeopleRole>(
                PublicPeopleRole.fromDatabase((json['role'] as String)),
              )
            : const SqlValue.absent(),
      );

  static const schemaId = 'PublicPeopleInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
      'role': JsonSchema.string(enumValues: <String>['admin', 'member']),
    },
    required: <String>['name', 'email'],
    additionalProperties: false,
  );

  final SqlValue<PublicPeopleId> id;

  final String name;

  final String email;

  final SqlValue<PublicPeopleRole> role;

  PublicPeopleInsert copyWith({
    SqlValue<PublicPeopleId>? id,
    String? name,
    String? email,
    SqlValue<PublicPeopleRole>? role,
  }) {
    return PublicPeopleInsert(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    'name': name,
    'email': email,
    if (role.isPresent) 'role': role.value?.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    'name': name,
    'email': email,
    if (role.isPresent) 'role': role.value?.value,
  };

  @override
  String toString() =>
      'PublicPeopleInsert(id: $id, name: $name, email: $email, role: $role)';
}

final class PublicPeopleUpdate implements JsonEncodable {
  const PublicPeopleUpdate({
    this.id = const SqlValue.absent(),
    this.name = const SqlValue.absent(),
    this.email = const SqlValue.absent(),
    this.role = const SqlValue.absent(),
  });

  factory PublicPeopleUpdate.decode(Object? value) =>
      PublicPeopleUpdate.fromJson(readJsonObject(value));

  factory PublicPeopleUpdate.fromJson(Map<String, Object?> json) =>
      PublicPeopleUpdate(
        id: json.containsKey('id')
            ? SqlValue<PublicPeopleId>(
                PublicPeopleId((json['id'] as num).toInt()),
              )
            : const SqlValue.absent(),
        name: json.containsKey('name')
            ? SqlValue<String>((json['name'] as String))
            : const SqlValue.absent(),
        email: json.containsKey('email')
            ? SqlValue<String>((json['email'] as String))
            : const SqlValue.absent(),
        role: json.containsKey('role')
            ? SqlValue<PublicPeopleRole>(
                PublicPeopleRole.fromDatabase((json['role'] as String)),
              )
            : const SqlValue.absent(),
      );

  static const schemaId = 'PublicPeopleUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.integer(),
      'name': JsonSchema.string(),
      'email': JsonSchema.string(),
      'role': JsonSchema.string(enumValues: <String>['admin', 'member']),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<PublicPeopleId> id;

  final SqlValue<String> name;

  final SqlValue<String> email;

  final SqlValue<PublicPeopleRole> role;

  PublicPeopleUpdate copyWith({
    SqlValue<PublicPeopleId>? id,
    SqlValue<String>? name,
    SqlValue<String>? email,
    SqlValue<PublicPeopleRole>? role,
  }) {
    return PublicPeopleUpdate(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (role.isPresent) 'role': role.value?.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value?.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (role.isPresent) 'role': role.value?.value,
  };

  @override
  String toString() =>
      'PublicPeopleUpdate(id: $id, name: $name, email: $email, role: $role)';
}

final class PublicPeopleTable
    extends SqlTable<PublicPeopleRow, PublicPeopleInsert, PublicPeopleUpdate> {
  const PublicPeopleTable._();

  static const table = PublicPeopleTable._();

  static final id = SqlColumn<PublicPeopleId>(
    table: table,
    name: 'id',
    nullable: false,
    databaseType: 'int4',
  );

  static final nameColumn = SqlColumn<String>(
    table: table,
    name: 'name',
    nullable: false,
    databaseType: 'text',
  );

  static final email = SqlColumn<String>(
    table: table,
    name: 'email',
    nullable: false,
    databaseType: 'text',
  );

  static final role = SqlColumn<String>(
    table: table,
    name: 'role',
    nullable: false,
    databaseType: 'text',
  );

  @override
  String get name => 'people';

  @override
  String? get schema => 'public';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    id.asObjectColumn,
    nameColumn.asObjectColumn,
    email.asObjectColumn,
    role.asObjectColumn,
  ];

  @override
  PublicPeopleRow mapRow(SqlRow row, {String prefix = ''}) =>
      PublicPeopleRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(PublicPeopleInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(PublicPeopleUpdate value) =>
      value.toColumns();
}
