import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

final class DartEdgeSchemaMigrationsRow implements JsonEncodable {
  const DartEdgeSchemaMigrationsRow({
    required this.version,
    required this.name,
    required this.appliedAt,
  });

  factory DartEdgeSchemaMigrationsRow.fromSqlRow(
    SqlRow row, {
    String prefix = '',
  }) => DartEdgeSchemaMigrationsRow(
    version: row.readNullable<String>('${prefix}version'),
    name: row.read<String>('${prefix}name'),
    appliedAt: row.read<String>('${prefix}applied_at'),
  );

  factory DartEdgeSchemaMigrationsRow.fromColumns(
    Map<String, Object?> columns, {
    String prefix = '',
  }) => DartEdgeSchemaMigrationsRow.fromSqlRow(SqlRow(columns), prefix: prefix);

  factory DartEdgeSchemaMigrationsRow.fromJson(Map<String, Object?> json) =>
      DartEdgeSchemaMigrationsRow(
        version: json['version'] == null ? null : (json['version'] as String),
        name: (json['name'] as String),
        appliedAt: (json['applied_at'] as String),
      );

  static const schemaId = 'DartEdgeSchemaMigrationsRow';

  static const schemaRef = JsonSchema.ref(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'version': JsonSchema.string(nullable: true),
      'name': JsonSchema.string(),
      'applied_at': JsonSchema.string(),
    },
    required: <String>['version', 'name', 'applied_at'],
    additionalProperties: false,
  );

  final String? version;

  final String name;

  final String appliedAt;

  DartEdgeSchemaMigrationsRow copyWith({
    SqlValue<String?>? version,
    String? name,
    String? appliedAt,
  }) {
    return DartEdgeSchemaMigrationsRow(
      version: version == null || !version.isPresent
          ? this.version
          : version.value,
      name: name ?? this.name,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    'version': version,
    'name': name,
    'applied_at': appliedAt,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'name': name,
    'applied_at': appliedAt,
  };

  @override
  String toString() =>
      'DartEdgeSchemaMigrationsRow(version: $version, name: $name, appliedAt: $appliedAt)';
}

final class DartEdgeSchemaMigrationsInsert implements JsonEncodable {
  const DartEdgeSchemaMigrationsInsert({
    this.version = const SqlValue.absent(),
    required this.name,
    this.appliedAt = const SqlValue.absent(),
  });

  factory DartEdgeSchemaMigrationsInsert.fromJson(Map<String, Object?> json) =>
      DartEdgeSchemaMigrationsInsert(
        version: json.containsKey('version')
            ? SqlValue<String?>(
                json['version'] == null ? null : (json['version'] as String),
              )
            : const SqlValue.absent(),
        name: (json['name'] as String),
        appliedAt: json.containsKey('applied_at')
            ? SqlValue<String>((json['applied_at'] as String))
            : const SqlValue.absent(),
      );

  static const schemaId = 'DartEdgeSchemaMigrationsInsert';

  static const schemaRef = JsonSchema.ref(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'version': JsonSchema.string(nullable: true),
      'name': JsonSchema.string(),
      'applied_at': JsonSchema.string(),
    },
    required: <String>['name'],
    additionalProperties: false,
  );

  final SqlValue<String?> version;

  final String name;

  final SqlValue<String> appliedAt;

  DartEdgeSchemaMigrationsInsert copyWith({
    SqlValue<String?>? version,
    String? name,
    SqlValue<String>? appliedAt,
  }) {
    return DartEdgeSchemaMigrationsInsert(
      version: version ?? this.version,
      name: name ?? this.name,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (version.isPresent) 'version': version.value,
    'name': name,
    if (appliedAt.isPresent) 'applied_at': appliedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (version.isPresent) 'version': version.value,
    'name': name,
    if (appliedAt.isPresent) 'applied_at': appliedAt.value,
  };

  @override
  String toString() =>
      'DartEdgeSchemaMigrationsInsert(version: $version, name: $name, appliedAt: $appliedAt)';
}

final class DartEdgeSchemaMigrationsUpdate implements JsonEncodable {
  const DartEdgeSchemaMigrationsUpdate({
    this.version = const SqlValue.absent(),
    this.name = const SqlValue.absent(),
    this.appliedAt = const SqlValue.absent(),
  });

  factory DartEdgeSchemaMigrationsUpdate.fromJson(Map<String, Object?> json) =>
      DartEdgeSchemaMigrationsUpdate(
        version: json.containsKey('version')
            ? SqlValue<String?>(
                json['version'] == null ? null : (json['version'] as String),
              )
            : const SqlValue.absent(),
        name: json.containsKey('name')
            ? SqlValue<String>((json['name'] as String))
            : const SqlValue.absent(),
        appliedAt: json.containsKey('applied_at')
            ? SqlValue<String>((json['applied_at'] as String))
            : const SqlValue.absent(),
      );

  static const schemaId = 'DartEdgeSchemaMigrationsUpdate';

  static const schemaRef = JsonSchema.ref(schemaId);

  static const jsonSchema = JsonSchema.object(
    id: schemaId,
    properties: <String, JsonSchema>{
      'version': JsonSchema.string(nullable: true),
      'name': JsonSchema.string(),
      'applied_at': JsonSchema.string(),
    },
    required: <String>[],
    additionalProperties: false,
  );

  final SqlValue<String?> version;

  final SqlValue<String> name;

  final SqlValue<String> appliedAt;

  DartEdgeSchemaMigrationsUpdate copyWith({
    SqlValue<String?>? version,
    SqlValue<String>? name,
    SqlValue<String>? appliedAt,
  }) {
    return DartEdgeSchemaMigrationsUpdate(
      version: version ?? this.version,
      name: name ?? this.name,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  Map<String, Object?> toColumns() => <String, Object?>{
    if (version.isPresent) 'version': version.value,
    if (name.isPresent) 'name': name.value,
    if (appliedAt.isPresent) 'applied_at': appliedAt.value,
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    if (version.isPresent) 'version': version.value,
    if (name.isPresent) 'name': name.value,
    if (appliedAt.isPresent) 'applied_at': appliedAt.value,
  };

  @override
  String toString() =>
      'DartEdgeSchemaMigrationsUpdate(version: $version, name: $name, appliedAt: $appliedAt)';
}

final class DartEdgeSchemaMigrationsTable
    extends
        SqlTable<
          DartEdgeSchemaMigrationsRow,
          DartEdgeSchemaMigrationsInsert,
          DartEdgeSchemaMigrationsUpdate
        > {
  const DartEdgeSchemaMigrationsTable._();

  static const table = DartEdgeSchemaMigrationsTable._();

  static final version = SqlColumn<String>(
    table: table,
    name: 'version',
    nullable: true,
  );

  static final nameColumn = SqlColumn<String>(
    table: table,
    name: 'name',
    nullable: false,
  );

  static final appliedAt = SqlColumn<String>(
    table: table,
    name: 'applied_at',
    nullable: false,
  );

  @override
  String get name => 'dart_edge_schema_migrations';

  @override
  String? get schema => null;

  @override
  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[
    version.asObjectColumn,
    nameColumn.asObjectColumn,
    appliedAt.asObjectColumn,
  ];

  @override
  DartEdgeSchemaMigrationsRow mapRow(SqlRow row, {String prefix = ''}) =>
      DartEdgeSchemaMigrationsRow.fromSqlRow(row, prefix: prefix);

  @override
  Map<String, Object?> encodeInsert(DartEdgeSchemaMigrationsInsert value) =>
      value.toColumns();

  @override
  Map<String, Object?> encodeUpdate(DartEdgeSchemaMigrationsUpdate value) =>
      value.toColumns();
}
