import '../codegen/sql_codegen_config.dart';

/// Schema snapshot returned from an introspector.
final class IntrospectedDatabase {
  const IntrospectedDatabase({required this.dialect, required this.tables});

  factory IntrospectedDatabase.fromJson(Map<String, Object?> json) {
    return IntrospectedDatabase(
      dialect: SqlCodegenDialect.values.byName(json['dialect']! as String),
      tables: [
        for (final table in json['tables']! as List<Object?>)
          IntrospectedTable.fromJson(table! as Map<String, Object?>),
      ],
    );
  }

  /// Dialect the schema came from.
  final SqlCodegenDialect dialect;

  /// Introspected tables.
  final List<IntrospectedTable> tables;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'dialect': dialect.name,
      'tables': [for (final table in tables) table.toJson()],
    };
  }
}

/// Introspected table description.
final class IntrospectedTable {
  const IntrospectedTable({
    required this.name,
    required this.columns,
    this.schema,
  });

  factory IntrospectedTable.fromJson(Map<String, Object?> json) {
    return IntrospectedTable(
      name: json['name']! as String,
      schema: json['schema'] as String?,
      columns: [
        for (final column in json['columns']! as List<Object?>)
          IntrospectedColumn.fromJson(column! as Map<String, Object?>),
      ],
    );
  }

  /// Table name without schema qualification.
  final String name;

  /// Optional schema name.
  final String? schema;

  /// Columns that belong to the table.
  final List<IntrospectedColumn> columns;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      if (schema case final schema?) 'schema': schema,
      'columns': [for (final column in columns) column.toJson()],
    };
  }
}

/// Introspected column description.
final class IntrospectedColumn {
  const IntrospectedColumn({
    required this.name,
    required this.databaseType,
    required this.dartType,
    this.nullable = false,
    this.hasDefault = false,
    this.primaryKey = false,
  });

  factory IntrospectedColumn.fromJson(Map<String, Object?> json) {
    return IntrospectedColumn(
      name: json['name']! as String,
      databaseType: json['databaseType']! as String,
      dartType: json['dartType']! as String,
      nullable: json['nullable'] as bool? ?? false,
      hasDefault: json['hasDefault'] as bool? ?? false,
      primaryKey: json['primaryKey'] as bool? ?? false,
    );
  }

  /// Column name.
  final String name;

  /// Database-native type string.
  final String databaseType;

  /// Dart type string chosen for generated source.
  final String dartType;

  /// Whether the column may contain `NULL`.
  final bool nullable;

  /// Whether the column has a database default.
  final bool hasDefault;

  /// Whether the column is part of the primary key.
  final bool primaryKey;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'databaseType': databaseType,
      'dartType': dartType,
      if (nullable) 'nullable': true,
      if (hasDefault) 'hasDefault': true,
      if (primaryKey) 'primaryKey': true,
    };
  }
}
