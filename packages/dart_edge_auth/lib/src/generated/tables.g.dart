// GENERATED CODE - DO NOT MODIFY BY HAND.

part of '../dart_edge_auth.dart';

final class DartEdgeAuthSessionsTable
    extends
        SqlTable<
          DartEdgeAuthSession,
          Map<String, Object?>,
          Map<String, Object?>
        > {
  const DartEdgeAuthSessionsTable._({this.schema = null});

  const DartEdgeAuthSessionsTable.withSchema(this.schema);

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
  String get name => 'sessions';

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
  DartEdgeAuthSession mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthSession.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(Map<String, Object?> value) => value;

  @override
  Map<String, Object?> encodeUpdate(Map<String, Object?> value) => value;
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

final class DartEdgeAuthUsersTable
    extends
        SqlTable<DartEdgeAuthUser, Map<String, Object?>, Map<String, Object?>> {
  const DartEdgeAuthUsersTable._({this.schema = null});

  const DartEdgeAuthUsersTable.withSchema(this.schema);

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
  String get name => 'users';

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
  DartEdgeAuthUser mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthUser.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(Map<String, Object?> value) => value;

  @override
  Map<String, Object?> encodeUpdate(Map<String, Object?> value) => value;
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

extension DartEdgeAuthSchemaTables on DartEdgeAuthSchema {
  DartEdgeAuthSessionsTable get sessions =>
      DartEdgeAuthSessionsTable.withSchema(
        databaseSchema ?? DartEdgeAuthSessionsTable.table.schema,
      );

  DartEdgeAuthUsersTable get users => DartEdgeAuthUsersTable.withSchema(
    databaseSchema ?? DartEdgeAuthUsersTable.table.schema,
  );
}
