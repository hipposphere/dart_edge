import 'package:dart_edge_core/dart_edge_core.dart';

final class DartEdgeAuthUserRow implements JsonEncodable {
  const DartEdgeAuthUserRow({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.image,
    required this.createdAt,
    required this.updatedAt,
    required this.role,
    required this.banned,
    required this.banReason,
    required this.banExpires,
    required this.phoneNumber,
    required this.phoneNumberVerified,
  });

  factory DartEdgeAuthUserRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthUserRow(
        id: row.read<String>('${prefix}id'),
        name: row.read<String>('${prefix}name'),
        email: row.read<String>('${prefix}email'),
        emailVerified: row.read<bool>('${prefix}emailVerified'),
        image: row.readNullable<String>('${prefix}image'),
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
        role: row.readNullable<String>('${prefix}role'),
        banned: row.readNullable<bool>('${prefix}banned'),
        banReason: row.readNullable<String>('${prefix}banReason'),
        banExpires: switch (row.readNullable<Object?>('${prefix}banExpires')) {
          null => null,
          final DateTime value => value,
          final String value => DateTime.parse(value),
          final value => value as DateTime,
        },
        phoneNumber: row.readNullable<String>('${prefix}phoneNumber'),
        phoneNumberVerified: row.readNullable<bool>(
          '${prefix}phoneNumberVerified',
        ),
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
        createdAt: DateTime.parse((json['createdAt'] as String)),
        updatedAt: DateTime.parse((json['updatedAt'] as String)),
        role: json['role'] == null ? null : (json['role'] as String),
        banned: json['banned'] == null ? null : (json['banned'] as bool),
        banReason: json['banReason'] == null
            ? null
            : (json['banReason'] as String),
        banExpires: json['banExpires'] == null
            ? null
            : DateTime.parse((json['banExpires'] as String)),
        phoneNumber: json['phoneNumber'] == null
            ? null
            : (json['phoneNumber'] as String),
        phoneNumberVerified: json['phoneNumberVerified'] == null
            ? null
            : (json['phoneNumberVerified'] as bool),
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
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
      'role': JsonSchema.string(nullable: true),
      'banned': JsonSchema.boolean(nullable: true),
      'banReason': JsonSchema.string(nullable: true),
      'banExpires': JsonSchema.string(nullable: true, format: 'date-time'),
      'phoneNumber': JsonSchema.string(nullable: true),
      'phoneNumberVerified': JsonSchema.boolean(nullable: true),
    },
    required: <String>[
      'id',
      'name',
      'email',
      'emailVerified',
      'image',
      'createdAt',
      'updatedAt',
      'role',
      'banned',
      'banReason',
      'banExpires',
      'phoneNumber',
      'phoneNumberVerified',
    ],
    additionalProperties: false,
  );

  final String id;

  final String name;

  final String email;

  final bool emailVerified;

  final String? image;

  final DateTime createdAt;

  final DateTime updatedAt;

  final String? role;

  final bool? banned;

  final String? banReason;

  final DateTime? banExpires;

  final String? phoneNumber;

  final bool? phoneNumberVerified;

  DartEdgeAuthUserRow copyWith({
    String? id,
    String? name,
    String? email,
    bool? emailVerified,
    SqlValue<String?>? image,
    DateTime? createdAt,
    DateTime? updatedAt,
    SqlValue<String?>? role,
    SqlValue<bool?>? banned,
    SqlValue<String?>? banReason,
    SqlValue<DateTime?>? banExpires,
    SqlValue<String?>? phoneNumber,
    SqlValue<bool?>? phoneNumberVerified,
  }) {
    return DartEdgeAuthUserRow(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image == null || !image.isPresent ? this.image : image.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires,
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires?.toIso8601String(),
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserRow(id: $id, name: $name, email: $email, emailVerified: $emailVerified, image: $image, createdAt: $createdAt, updatedAt: $updatedAt, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, phoneNumber: $phoneNumber, phoneNumberVerified: $phoneNumberVerified)';
}

final class DartEdgeAuthUserInsert implements JsonEncodable {
  const DartEdgeAuthUserInsert({
    this.id = const SqlValue.absent(),
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.image,
    required this.createdAt,
    required this.updatedAt,
    required this.role,
    required this.banned,
    required this.banReason,
    required this.banExpires,
    required this.phoneNumber,
    required this.phoneNumberVerified,
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
        emailVerified: (json['emailVerified'] as bool),
        image: json['image'] == null ? null : (json['image'] as String),
        createdAt: DateTime.parse((json['createdAt'] as String)),
        updatedAt: DateTime.parse((json['updatedAt'] as String)),
        role: json['role'] == null ? null : (json['role'] as String),
        banned: json['banned'] == null ? null : (json['banned'] as bool),
        banReason: json['banReason'] == null
            ? null
            : (json['banReason'] as String),
        banExpires: json['banExpires'] == null
            ? null
            : DateTime.parse((json['banExpires'] as String)),
        phoneNumber: json['phoneNumber'] == null
            ? null
            : (json['phoneNumber'] as String),
        phoneNumberVerified: json['phoneNumberVerified'] == null
            ? null
            : (json['phoneNumberVerified'] as bool),
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
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
      'role': JsonSchema.string(nullable: true),
      'banned': JsonSchema.boolean(nullable: true),
      'banReason': JsonSchema.string(nullable: true),
      'banExpires': JsonSchema.string(nullable: true, format: 'date-time'),
      'phoneNumber': JsonSchema.string(nullable: true),
      'phoneNumberVerified': JsonSchema.boolean(nullable: true),
    },
    required: <String>[
      'name',
      'email',
      'emailVerified',
      'image',
      'createdAt',
      'updatedAt',
      'role',
      'banned',
      'banReason',
      'banExpires',
      'phoneNumber',
      'phoneNumberVerified',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String name;

  final String email;

  final bool emailVerified;

  final String? image;

  final DateTime createdAt;

  final DateTime updatedAt;

  final String? role;

  final bool? banned;

  final String? banReason;

  final DateTime? banExpires;

  final String? phoneNumber;

  final bool? phoneNumberVerified;

  DartEdgeAuthUserInsert copyWith({
    SqlValue<String>? id,
    String? name,
    String? email,
    bool? emailVerified,
    SqlValue<String?>? image,
    DateTime? createdAt,
    DateTime? updatedAt,
    SqlValue<String?>? role,
    SqlValue<bool?>? banned,
    SqlValue<String?>? banReason,
    SqlValue<DateTime?>? banExpires,
    SqlValue<String?>? phoneNumber,
    SqlValue<bool?>? phoneNumberVerified,
  }) {
    return DartEdgeAuthUserInsert(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image == null || !image.isPresent ? this.image : image.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires,
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'name': name,
    'email': email,
    'emailVerified': emailVerified,
    'image': image,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'role': role,
    'banned': banned,
    'banReason': banReason,
    'banExpires': banExpires?.toIso8601String(),
    'phoneNumber': phoneNumber,
    'phoneNumberVerified': phoneNumberVerified,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserInsert(id: $id, name: $name, email: $email, emailVerified: $emailVerified, image: $image, createdAt: $createdAt, updatedAt: $updatedAt, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, phoneNumber: $phoneNumber, phoneNumberVerified: $phoneNumberVerified)';
}

final class DartEdgeAuthUserUpdate implements JsonEncodable {
  const DartEdgeAuthUserUpdate({
    this.id = const SqlValue.absent(),
    this.name = const SqlValue.absent(),
    this.email = const SqlValue.absent(),
    this.emailVerified = const SqlValue.absent(),
    this.image = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.updatedAt = const SqlValue.absent(),
    this.role = const SqlValue.absent(),
    this.banned = const SqlValue.absent(),
    this.banReason = const SqlValue.absent(),
    this.banExpires = const SqlValue.absent(),
    this.phoneNumber = const SqlValue.absent(),
    this.phoneNumberVerified = const SqlValue.absent(),
  });

  factory DartEdgeAuthUserUpdate.decode(Object? value) =>
      DartEdgeAuthUserUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthUserUpdate.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthUserUpdate(
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
        createdAt: json.containsKey('createdAt')
            ? SqlValue<DateTime>(DateTime.parse((json['createdAt'] as String)))
            : const SqlValue.absent(),
        updatedAt: json.containsKey('updatedAt')
            ? SqlValue<DateTime>(DateTime.parse((json['updatedAt'] as String)))
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
                json['banReason'] == null
                    ? null
                    : (json['banReason'] as String),
              )
            : const SqlValue.absent(),
        banExpires: json.containsKey('banExpires')
            ? SqlValue<DateTime?>(
                json['banExpires'] == null
                    ? null
                    : DateTime.parse((json['banExpires'] as String)),
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
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
      'role': JsonSchema.string(nullable: true),
      'banned': JsonSchema.boolean(nullable: true),
      'banReason': JsonSchema.string(nullable: true),
      'banExpires': JsonSchema.string(nullable: true, format: 'date-time'),
      'phoneNumber': JsonSchema.string(nullable: true),
      'phoneNumberVerified': JsonSchema.boolean(nullable: true),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<String> name;

  final SqlValue<String> email;

  final SqlValue<bool> emailVerified;

  final SqlValue<String?> image;

  final SqlValue<DateTime> createdAt;

  final SqlValue<DateTime> updatedAt;

  final SqlValue<String?> role;

  final SqlValue<bool?> banned;

  final SqlValue<String?> banReason;

  final SqlValue<DateTime?> banExpires;

  final SqlValue<String?> phoneNumber;

  final SqlValue<bool?> phoneNumberVerified;

  DartEdgeAuthUserUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String>? name,
    SqlValue<String>? email,
    SqlValue<bool>? emailVerified,
    SqlValue<String?>? image,
    SqlValue<DateTime>? createdAt,
    SqlValue<DateTime>? updatedAt,
    SqlValue<String?>? role,
    SqlValue<bool?>? banned,
    SqlValue<String?>? banReason,
    SqlValue<DateTime?>? banExpires,
    SqlValue<String?>? phoneNumber,
    SqlValue<bool?>? phoneNumberVerified,
  }) {
    return DartEdgeAuthUserUpdate(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      image: image ?? this.image,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      banned: banned ?? this.banned,
      banReason: banReason ?? this.banReason,
      banExpires: banExpires ?? this.banExpires,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneNumberVerified: phoneNumberVerified ?? this.phoneNumberVerified,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (emailVerified.isPresent) 'emailVerified': emailVerified.value,
    if (image.isPresent) 'image': image.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    if (banReason.isPresent) 'banReason': banReason.value,
    if (banExpires.isPresent) 'banExpires': banExpires.value,
    if (phoneNumber.isPresent) 'phoneNumber': phoneNumber.value,
    if (phoneNumberVerified.isPresent)
      'phoneNumberVerified': phoneNumberVerified.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (name.isPresent) 'name': name.value,
    if (email.isPresent) 'email': email.value,
    if (emailVerified.isPresent) 'emailVerified': emailVerified.value,
    if (image.isPresent) 'image': image.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value?.toIso8601String(),
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value?.toIso8601String(),
    if (role.isPresent) 'role': role.value,
    if (banned.isPresent) 'banned': banned.value,
    if (banReason.isPresent) 'banReason': banReason.value,
    if (banExpires.isPresent) 'banExpires': banExpires.value?.toIso8601String(),
    if (phoneNumber.isPresent) 'phoneNumber': phoneNumber.value,
    if (phoneNumberVerified.isPresent)
      'phoneNumberVerified': phoneNumberVerified.value,
  };

  @override
  String toString() =>
      'DartEdgeAuthUserUpdate(id: $id, name: $name, email: $email, emailVerified: $emailVerified, image: $image, createdAt: $createdAt, updatedAt: $updatedAt, role: $role, banned: $banned, banReason: $banReason, banExpires: $banExpires, phoneNumber: $phoneNumber, phoneNumberVerified: $phoneNumberVerified)';
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
    databaseType: 'text',
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

  static final emailVerified = SqlColumn<bool>(
    table: table,
    name: 'emailVerified',
    nullable: false,
    databaseType: 'bool',
  );

  static final image = SqlColumn<String>(
    table: table,
    name: 'image',
    nullable: true,
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

  static final role = SqlColumn<String>(
    table: table,
    name: 'role',
    nullable: true,
    databaseType: 'text',
  );

  static final banned = SqlColumn<bool>(
    table: table,
    name: 'banned',
    nullable: true,
    databaseType: 'bool',
  );

  static final banReason = SqlColumn<String>(
    table: table,
    name: 'banReason',
    nullable: true,
    databaseType: 'text',
  );

  static final banExpires = SqlColumn<DateTime>(
    table: table,
    name: 'banExpires',
    nullable: true,
    databaseType: 'timestamptz',
  );

  static final phoneNumber = SqlColumn<String>(
    table: table,
    name: 'phoneNumber',
    nullable: true,
    databaseType: 'text',
  );

  static final phoneNumberVerified = SqlColumn<bool>(
    table: table,
    name: 'phoneNumberVerified',
    nullable: true,
    databaseType: 'bool',
  );

  @override
  String get name => 'user';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'text').asObjectColumn,
    column<String>(
      'name',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'email',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<bool>(
      'emailVerified',
      nullable: false,
      databaseType: 'bool',
    ).asObjectColumn,
    column<String>(
      'image',
      nullable: true,
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
    column<String>('role', nullable: true, databaseType: 'text').asObjectColumn,
    column<bool>('banned', nullable: true, databaseType: 'bool').asObjectColumn,
    column<String>(
      'banReason',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<DateTime>(
      'banExpires',
      nullable: true,
      databaseType: 'timestamptz',
    ).asObjectColumn,
    column<String>(
      'phoneNumber',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<bool>(
      'phoneNumberVerified',
      nullable: true,
      databaseType: 'bool',
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
      column<String>('id', nullable: false, databaseType: 'text');

  SqlColumn<String> get nameColumn =>
      column<String>('name', nullable: false, databaseType: 'text');

  SqlColumn<String> get email =>
      column<String>('email', nullable: false, databaseType: 'text');

  SqlColumn<bool> get emailVerified =>
      column<bool>('emailVerified', nullable: false, databaseType: 'bool');

  SqlColumn<String> get image =>
      column<String>('image', nullable: true, databaseType: 'text');

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

  SqlColumn<String> get role =>
      column<String>('role', nullable: true, databaseType: 'text');

  SqlColumn<bool> get banned =>
      column<bool>('banned', nullable: true, databaseType: 'bool');

  SqlColumn<String> get banReason =>
      column<String>('banReason', nullable: true, databaseType: 'text');

  SqlColumn<DateTime> get banExpires => column<DateTime>(
    'banExpires',
    nullable: true,
    databaseType: 'timestamptz',
  );

  SqlColumn<String> get phoneNumber =>
      column<String>('phoneNumber', nullable: true, databaseType: 'text');

  SqlColumn<bool> get phoneNumberVerified =>
      column<bool>('phoneNumberVerified', nullable: true, databaseType: 'bool');
}
