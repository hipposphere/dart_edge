import '../codegen/sql_codegen_config.dart';

/// Schema snapshot returned from an introspector.
final class IntrospectedDatabase {
  const IntrospectedDatabase({required this.dialect, required this.tables});

  /// Dialect the schema came from.
  final SqlCodegenDialect dialect;

  /// Introspected tables.
  final List<IntrospectedTable> tables;
}

/// Introspected table description.
final class IntrospectedTable {
  const IntrospectedTable({
    required this.name,
    required this.columns,
    this.schema,
  });

  /// Table name without schema qualification.
  final String name;

  /// Optional schema name.
  final String? schema;

  /// Columns that belong to the table.
  final List<IntrospectedColumn> columns;
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
}
