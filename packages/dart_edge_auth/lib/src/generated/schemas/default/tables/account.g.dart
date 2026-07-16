import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:json_schema/json_schema.dart';

final class DartEdgeAuthAccountRow implements JsonEncodable {
  const DartEdgeAuthAccountRow({
    required this.id,
    required this.accountId,
    required this.providerId,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.scope,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthAccountRow.fromSqlRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthAccountRow(
        id: row.read<String>('${prefix}id'),
        accountId: row.read<String>('${prefix}accountId'),
        providerId: row.read<String>('${prefix}providerId'),
        userId: row.read<String>('${prefix}userId'),
        accessToken: row.readNullable<String>('${prefix}accessToken'),
        refreshToken: row.readNullable<String>('${prefix}refreshToken'),
        idToken: row.readNullable<String>('${prefix}idToken'),
        accessTokenExpiresAt: switch (row.readNullable<Object?>(
          '${prefix}accessTokenExpiresAt',
        )) {
          null => null,
          final DateTime value => value,
          final String value => DateTime.parse(value),
          final value => value as DateTime,
        },
        refreshTokenExpiresAt: switch (row.readNullable<Object?>(
          '${prefix}refreshTokenExpiresAt',
        )) {
          null => null,
          final DateTime value => value,
          final String value => DateTime.parse(value),
          final value => value as DateTime,
        },
        scope: row.readNullable<String>('${prefix}scope'),
        password: row.readNullable<String>('${prefix}password'),
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

  factory DartEdgeAuthAccountRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeAuthAccountRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeAuthAccountRow.decode(Object? value) =>
      DartEdgeAuthAccountRow.fromJson(readJsonObject(value));

  factory DartEdgeAuthAccountRow.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthAccountRow(
        id: (json['id'] as String),
        accountId: (json['accountId'] as String),
        providerId: (json['providerId'] as String),
        userId: (json['userId'] as String),
        accessToken: json['accessToken'] == null
            ? null
            : (json['accessToken'] as String),
        refreshToken: json['refreshToken'] == null
            ? null
            : (json['refreshToken'] as String),
        idToken: json['idToken'] == null ? null : (json['idToken'] as String),
        accessTokenExpiresAt: json['accessTokenExpiresAt'] == null
            ? null
            : DateTime.parse((json['accessTokenExpiresAt'] as String)),
        refreshTokenExpiresAt: json['refreshTokenExpiresAt'] == null
            ? null
            : DateTime.parse((json['refreshTokenExpiresAt'] as String)),
        scope: json['scope'] == null ? null : (json['scope'] as String),
        password: json['password'] == null
            ? null
            : (json['password'] as String),
        createdAt: DateTime.parse((json['createdAt'] as String)),
        updatedAt: DateTime.parse((json['updatedAt'] as String)),
      );

  static const schemaId = 'DartEdgeAuthAccountRow';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'accountId': JsonSchema.string(),
      'providerId': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'accessToken': JsonSchema.string(nullable: true),
      'refreshToken': JsonSchema.string(nullable: true),
      'idToken': JsonSchema.string(nullable: true),
      'accessTokenExpiresAt': JsonSchema.string(
        nullable: true,
        format: 'date-time',
      ),
      'refreshTokenExpiresAt': JsonSchema.string(
        nullable: true,
        format: 'date-time',
      ),
      'scope': JsonSchema.string(nullable: true),
      'password': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
    },
    required: <String>[
      'id',
      'accountId',
      'providerId',
      'userId',
      'accessToken',
      'refreshToken',
      'idToken',
      'accessTokenExpiresAt',
      'refreshTokenExpiresAt',
      'scope',
      'password',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final String id;

  final String accountId;

  final String providerId;

  final String userId;

  final String? accessToken;

  final String? refreshToken;

  final String? idToken;

  final DateTime? accessTokenExpiresAt;

  final DateTime? refreshTokenExpiresAt;

  final String? scope;

  final String? password;

  final DateTime createdAt;

  final DateTime updatedAt;

  DartEdgeAuthAccountRow copyWith({
    String? id,
    String? accountId,
    String? providerId,
    String? userId,
    SqlValue<String?>? accessToken,
    SqlValue<String?>? refreshToken,
    SqlValue<String?>? idToken,
    SqlValue<DateTime?>? accessTokenExpiresAt,
    SqlValue<DateTime?>? refreshTokenExpiresAt,
    SqlValue<String?>? scope,
    SqlValue<String?>? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DartEdgeAuthAccountRow(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      providerId: providerId ?? this.providerId,
      userId: userId ?? this.userId,
      accessToken: accessToken == null || !accessToken.isPresent
          ? this.accessToken
          : accessToken.value,
      refreshToken: refreshToken == null || !refreshToken.isPresent
          ? this.refreshToken
          : refreshToken.value,
      idToken: idToken == null || !idToken.isPresent
          ? this.idToken
          : idToken.value,
      accessTokenExpiresAt:
          accessTokenExpiresAt == null || !accessTokenExpiresAt.isPresent
          ? this.accessTokenExpiresAt
          : accessTokenExpiresAt.value,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt == null || !refreshTokenExpiresAt.isPresent
          ? this.refreshTokenExpiresAt
          : refreshTokenExpiresAt.value,
      scope: scope == null || !scope.isPresent ? this.scope : scope.value,
      password: password == null || !password.isPresent
          ? this.password
          : password.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'id': id,
    'accountId': accountId,
    'providerId': providerId,
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'accessTokenExpiresAt': accessTokenExpiresAt,
    'refreshTokenExpiresAt': refreshTokenExpiresAt,
    'scope': scope,
    'password': password,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'accountId': accountId,
    'providerId': providerId,
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
    'refreshTokenExpiresAt': refreshTokenExpiresAt?.toIso8601String(),
    'scope': scope,
    'password': password,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'DartEdgeAuthAccountRow(id: $id, accountId: $accountId, providerId: $providerId, userId: $userId, accessToken: $accessToken, refreshToken: $refreshToken, idToken: $idToken, accessTokenExpiresAt: $accessTokenExpiresAt, refreshTokenExpiresAt: $refreshTokenExpiresAt, scope: $scope, password: $password, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthAccountInsert implements JsonEncodable {
  const DartEdgeAuthAccountInsert({
    this.id = const SqlValue.absent(),
    required this.accountId,
    required this.providerId,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.scope,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DartEdgeAuthAccountInsert.decode(Object? value) =>
      DartEdgeAuthAccountInsert.fromJson(readJsonObject(value));

  factory DartEdgeAuthAccountInsert.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthAccountInsert(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        accountId: (json['accountId'] as String),
        providerId: (json['providerId'] as String),
        userId: (json['userId'] as String),
        accessToken: json['accessToken'] == null
            ? null
            : (json['accessToken'] as String),
        refreshToken: json['refreshToken'] == null
            ? null
            : (json['refreshToken'] as String),
        idToken: json['idToken'] == null ? null : (json['idToken'] as String),
        accessTokenExpiresAt: json['accessTokenExpiresAt'] == null
            ? null
            : DateTime.parse((json['accessTokenExpiresAt'] as String)),
        refreshTokenExpiresAt: json['refreshTokenExpiresAt'] == null
            ? null
            : DateTime.parse((json['refreshTokenExpiresAt'] as String)),
        scope: json['scope'] == null ? null : (json['scope'] as String),
        password: json['password'] == null
            ? null
            : (json['password'] as String),
        createdAt: DateTime.parse((json['createdAt'] as String)),
        updatedAt: DateTime.parse((json['updatedAt'] as String)),
      );

  static const schemaId = 'DartEdgeAuthAccountInsert';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'accountId': JsonSchema.string(),
      'providerId': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'accessToken': JsonSchema.string(nullable: true),
      'refreshToken': JsonSchema.string(nullable: true),
      'idToken': JsonSchema.string(nullable: true),
      'accessTokenExpiresAt': JsonSchema.string(
        nullable: true,
        format: 'date-time',
      ),
      'refreshTokenExpiresAt': JsonSchema.string(
        nullable: true,
        format: 'date-time',
      ),
      'scope': JsonSchema.string(nullable: true),
      'password': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
    },
    required: <String>[
      'accountId',
      'providerId',
      'userId',
      'accessToken',
      'refreshToken',
      'idToken',
      'accessTokenExpiresAt',
      'refreshTokenExpiresAt',
      'scope',
      'password',
      'createdAt',
      'updatedAt',
    ],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final String accountId;

  final String providerId;

  final String userId;

  final String? accessToken;

  final String? refreshToken;

  final String? idToken;

  final DateTime? accessTokenExpiresAt;

  final DateTime? refreshTokenExpiresAt;

  final String? scope;

  final String? password;

  final DateTime createdAt;

  final DateTime updatedAt;

  DartEdgeAuthAccountInsert copyWith({
    SqlValue<String>? id,
    String? accountId,
    String? providerId,
    String? userId,
    SqlValue<String?>? accessToken,
    SqlValue<String?>? refreshToken,
    SqlValue<String?>? idToken,
    SqlValue<DateTime?>? accessTokenExpiresAt,
    SqlValue<DateTime?>? refreshTokenExpiresAt,
    SqlValue<String?>? scope,
    SqlValue<String?>? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DartEdgeAuthAccountInsert(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      providerId: providerId ?? this.providerId,
      userId: userId ?? this.userId,
      accessToken: accessToken == null || !accessToken.isPresent
          ? this.accessToken
          : accessToken.value,
      refreshToken: refreshToken == null || !refreshToken.isPresent
          ? this.refreshToken
          : refreshToken.value,
      idToken: idToken == null || !idToken.isPresent
          ? this.idToken
          : idToken.value,
      accessTokenExpiresAt:
          accessTokenExpiresAt == null || !accessTokenExpiresAt.isPresent
          ? this.accessTokenExpiresAt
          : accessTokenExpiresAt.value,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt == null || !refreshTokenExpiresAt.isPresent
          ? this.refreshTokenExpiresAt
          : refreshTokenExpiresAt.value,
      scope: scope == null || !scope.isPresent ? this.scope : scope.value,
      password: password == null || !password.isPresent
          ? this.password
          : password.value,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'accountId': accountId,
    'providerId': providerId,
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'accessTokenExpiresAt': accessTokenExpiresAt,
    'refreshTokenExpiresAt': refreshTokenExpiresAt,
    'scope': scope,
    'password': password,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    'accountId': accountId,
    'providerId': providerId,
    'userId': userId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'idToken': idToken,
    'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
    'refreshTokenExpiresAt': refreshTokenExpiresAt?.toIso8601String(),
    'scope': scope,
    'password': password,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'DartEdgeAuthAccountInsert(id: $id, accountId: $accountId, providerId: $providerId, userId: $userId, accessToken: $accessToken, refreshToken: $refreshToken, idToken: $idToken, accessTokenExpiresAt: $accessTokenExpiresAt, refreshTokenExpiresAt: $refreshTokenExpiresAt, scope: $scope, password: $password, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthAccountUpdate implements JsonEncodable {
  const DartEdgeAuthAccountUpdate({
    this.id = const SqlValue.absent(),
    this.accountId = const SqlValue.absent(),
    this.providerId = const SqlValue.absent(),
    this.userId = const SqlValue.absent(),
    this.accessToken = const SqlValue.absent(),
    this.refreshToken = const SqlValue.absent(),
    this.idToken = const SqlValue.absent(),
    this.accessTokenExpiresAt = const SqlValue.absent(),
    this.refreshTokenExpiresAt = const SqlValue.absent(),
    this.scope = const SqlValue.absent(),
    this.password = const SqlValue.absent(),
    this.createdAt = const SqlValue.absent(),
    this.updatedAt = const SqlValue.absent(),
  });

  factory DartEdgeAuthAccountUpdate.decode(Object? value) =>
      DartEdgeAuthAccountUpdate.fromJson(readJsonObject(value));

  factory DartEdgeAuthAccountUpdate.fromJson(Map<String, Object?> json) =>
      DartEdgeAuthAccountUpdate(
        id: json.containsKey('id')
            ? SqlValue<String>((json['id'] as String))
            : const SqlValue.absent(),
        accountId: json.containsKey('accountId')
            ? SqlValue<String>((json['accountId'] as String))
            : const SqlValue.absent(),
        providerId: json.containsKey('providerId')
            ? SqlValue<String>((json['providerId'] as String))
            : const SqlValue.absent(),
        userId: json.containsKey('userId')
            ? SqlValue<String>((json['userId'] as String))
            : const SqlValue.absent(),
        accessToken: json.containsKey('accessToken')
            ? SqlValue<String?>(
                json['accessToken'] == null
                    ? null
                    : (json['accessToken'] as String),
              )
            : const SqlValue.absent(),
        refreshToken: json.containsKey('refreshToken')
            ? SqlValue<String?>(
                json['refreshToken'] == null
                    ? null
                    : (json['refreshToken'] as String),
              )
            : const SqlValue.absent(),
        idToken: json.containsKey('idToken')
            ? SqlValue<String?>(
                json['idToken'] == null ? null : (json['idToken'] as String),
              )
            : const SqlValue.absent(),
        accessTokenExpiresAt: json.containsKey('accessTokenExpiresAt')
            ? SqlValue<DateTime?>(
                json['accessTokenExpiresAt'] == null
                    ? null
                    : DateTime.parse((json['accessTokenExpiresAt'] as String)),
              )
            : const SqlValue.absent(),
        refreshTokenExpiresAt: json.containsKey('refreshTokenExpiresAt')
            ? SqlValue<DateTime?>(
                json['refreshTokenExpiresAt'] == null
                    ? null
                    : DateTime.parse((json['refreshTokenExpiresAt'] as String)),
              )
            : const SqlValue.absent(),
        scope: json.containsKey('scope')
            ? SqlValue<String?>(
                json['scope'] == null ? null : (json['scope'] as String),
              )
            : const SqlValue.absent(),
        password: json.containsKey('password')
            ? SqlValue<String?>(
                json['password'] == null ? null : (json['password'] as String),
              )
            : const SqlValue.absent(),
        createdAt: json.containsKey('createdAt')
            ? SqlValue<DateTime>(DateTime.parse((json['createdAt'] as String)))
            : const SqlValue.absent(),
        updatedAt: json.containsKey('updatedAt')
            ? SqlValue<DateTime>(DateTime.parse((json['updatedAt'] as String)))
            : const SqlValue.absent(),
      );

  static const schemaId = 'DartEdgeAuthAccountUpdate';

  static const schemaRef = JsonSchema.componentRef(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'id': JsonSchema.string(),
      'accountId': JsonSchema.string(),
      'providerId': JsonSchema.string(),
      'userId': JsonSchema.string(),
      'accessToken': JsonSchema.string(nullable: true),
      'refreshToken': JsonSchema.string(nullable: true),
      'idToken': JsonSchema.string(nullable: true),
      'accessTokenExpiresAt': JsonSchema.string(
        nullable: true,
        format: 'date-time',
      ),
      'refreshTokenExpiresAt': JsonSchema.string(
        nullable: true,
        format: 'date-time',
      ),
      'scope': JsonSchema.string(nullable: true),
      'password': JsonSchema.string(nullable: true),
      'createdAt': JsonSchema.string(format: 'date-time'),
      'updatedAt': JsonSchema.string(format: 'date-time'),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String> id;

  final SqlValue<String> accountId;

  final SqlValue<String> providerId;

  final SqlValue<String> userId;

  final SqlValue<String?> accessToken;

  final SqlValue<String?> refreshToken;

  final SqlValue<String?> idToken;

  final SqlValue<DateTime?> accessTokenExpiresAt;

  final SqlValue<DateTime?> refreshTokenExpiresAt;

  final SqlValue<String?> scope;

  final SqlValue<String?> password;

  final SqlValue<DateTime> createdAt;

  final SqlValue<DateTime> updatedAt;

  DartEdgeAuthAccountUpdate copyWith({
    SqlValue<String>? id,
    SqlValue<String>? accountId,
    SqlValue<String>? providerId,
    SqlValue<String>? userId,
    SqlValue<String?>? accessToken,
    SqlValue<String?>? refreshToken,
    SqlValue<String?>? idToken,
    SqlValue<DateTime?>? accessTokenExpiresAt,
    SqlValue<DateTime?>? refreshTokenExpiresAt,
    SqlValue<String?>? scope,
    SqlValue<String?>? password,
    SqlValue<DateTime>? createdAt,
    SqlValue<DateTime>? updatedAt,
  }) {
    return DartEdgeAuthAccountUpdate(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      providerId: providerId ?? this.providerId,
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      idToken: idToken ?? this.idToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
      scope: scope ?? this.scope,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (accountId.isPresent) 'accountId': accountId.value,
    if (providerId.isPresent) 'providerId': providerId.value,
    if (userId.isPresent) 'userId': userId.value,
    if (accessToken.isPresent) 'accessToken': accessToken.value,
    if (refreshToken.isPresent) 'refreshToken': refreshToken.value,
    if (idToken.isPresent) 'idToken': idToken.value,
    if (accessTokenExpiresAt.isPresent)
      'accessTokenExpiresAt': accessTokenExpiresAt.value,
    if (refreshTokenExpiresAt.isPresent)
      'refreshTokenExpiresAt': refreshTokenExpiresAt.value,
    if (scope.isPresent) 'scope': scope.value,
    if (password.isPresent) 'password': password.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value,
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (id.isPresent) 'id': id.value,
    if (accountId.isPresent) 'accountId': accountId.value,
    if (providerId.isPresent) 'providerId': providerId.value,
    if (userId.isPresent) 'userId': userId.value,
    if (accessToken.isPresent) 'accessToken': accessToken.value,
    if (refreshToken.isPresent) 'refreshToken': refreshToken.value,
    if (idToken.isPresent) 'idToken': idToken.value,
    if (accessTokenExpiresAt.isPresent)
      'accessTokenExpiresAt': accessTokenExpiresAt.value?.toIso8601String(),
    if (refreshTokenExpiresAt.isPresent)
      'refreshTokenExpiresAt': refreshTokenExpiresAt.value?.toIso8601String(),
    if (scope.isPresent) 'scope': scope.value,
    if (password.isPresent) 'password': password.value,
    if (createdAt.isPresent) 'createdAt': createdAt.value?.toIso8601String(),
    if (updatedAt.isPresent) 'updatedAt': updatedAt.value?.toIso8601String(),
  };

  @override
  String toString() =>
      'DartEdgeAuthAccountUpdate(id: $id, accountId: $accountId, providerId: $providerId, userId: $userId, accessToken: $accessToken, refreshToken: $refreshToken, idToken: $idToken, accessTokenExpiresAt: $accessTokenExpiresAt, refreshTokenExpiresAt: $refreshTokenExpiresAt, scope: $scope, password: $password, createdAt: $createdAt, updatedAt: $updatedAt)';
}

final class DartEdgeAuthAccountsTable
    extends
        SqlTable<
          DartEdgeAuthAccountRow,
          DartEdgeAuthAccountInsert,
          DartEdgeAuthAccountUpdate
        > {
  const DartEdgeAuthAccountsTable._() : schema = null;

  const DartEdgeAuthAccountsTable.withSchema(this.schema);

  @override
  final String? schema;

  static const table = DartEdgeAuthAccountsTable._();

  static final id = SqlColumn<String>(
    table: table,
    name: 'id',
    nullable: false,
    databaseType: 'text',
  );

  static final accountId = SqlColumn<String>(
    table: table,
    name: 'accountId',
    nullable: false,
    databaseType: 'text',
  );

  static final providerId = SqlColumn<String>(
    table: table,
    name: 'providerId',
    nullable: false,
    databaseType: 'text',
  );

  static final userId = SqlColumn<String>(
    table: table,
    name: 'userId',
    nullable: false,
    databaseType: 'text',
  );

  static final accessToken = SqlColumn<String>(
    table: table,
    name: 'accessToken',
    nullable: true,
    databaseType: 'text',
  );

  static final refreshToken = SqlColumn<String>(
    table: table,
    name: 'refreshToken',
    nullable: true,
    databaseType: 'text',
  );

  static final idToken = SqlColumn<String>(
    table: table,
    name: 'idToken',
    nullable: true,
    databaseType: 'text',
  );

  static final accessTokenExpiresAt = SqlColumn<DateTime>(
    table: table,
    name: 'accessTokenExpiresAt',
    nullable: true,
    databaseType: 'timestamptz',
  );

  static final refreshTokenExpiresAt = SqlColumn<DateTime>(
    table: table,
    name: 'refreshTokenExpiresAt',
    nullable: true,
    databaseType: 'timestamptz',
  );

  static final scope = SqlColumn<String>(
    table: table,
    name: 'scope',
    nullable: true,
    databaseType: 'text',
  );

  static final password = SqlColumn<String>(
    table: table,
    name: 'password',
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

  @override
  String get name => 'account';

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    column<String>('id', nullable: false, databaseType: 'text').asObjectColumn,
    column<String>(
      'accountId',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'providerId',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'userId',
      nullable: false,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'accessToken',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'refreshToken',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'idToken',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<DateTime>(
      'accessTokenExpiresAt',
      nullable: true,
      databaseType: 'timestamptz',
    ).asObjectColumn,
    column<DateTime>(
      'refreshTokenExpiresAt',
      nullable: true,
      databaseType: 'timestamptz',
    ).asObjectColumn,
    column<String>(
      'scope',
      nullable: true,
      databaseType: 'text',
    ).asObjectColumn,
    column<String>(
      'password',
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
  ];

  @override
  DartEdgeAuthAccountRow mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeAuthAccountRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(DartEdgeAuthAccountInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(DartEdgeAuthAccountUpdate value) =>
      value.toColumns();
}

extension DartEdgeAuthAccountsTableColumns on DartEdgeAuthAccountsTable {
  SqlColumn<String> get id =>
      column<String>('id', nullable: false, databaseType: 'text');

  SqlColumn<String> get accountId =>
      column<String>('accountId', nullable: false, databaseType: 'text');

  SqlColumn<String> get providerId =>
      column<String>('providerId', nullable: false, databaseType: 'text');

  SqlColumn<String> get userId =>
      column<String>('userId', nullable: false, databaseType: 'text');

  SqlColumn<String> get accessToken =>
      column<String>('accessToken', nullable: true, databaseType: 'text');

  SqlColumn<String> get refreshToken =>
      column<String>('refreshToken', nullable: true, databaseType: 'text');

  SqlColumn<String> get idToken =>
      column<String>('idToken', nullable: true, databaseType: 'text');

  SqlColumn<DateTime> get accessTokenExpiresAt => column<DateTime>(
    'accessTokenExpiresAt',
    nullable: true,
    databaseType: 'timestamptz',
  );

  SqlColumn<DateTime> get refreshTokenExpiresAt => column<DateTime>(
    'refreshTokenExpiresAt',
    nullable: true,
    databaseType: 'timestamptz',
  );

  SqlColumn<String> get scope =>
      column<String>('scope', nullable: true, databaseType: 'text');

  SqlColumn<String> get password =>
      column<String>('password', nullable: true, databaseType: 'text');

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
