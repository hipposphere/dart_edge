import '../codegen/sql_codegen_config.dart';

/// Schema snapshot returned from an introspector.
final class IntrospectedDatabase {
  const IntrospectedDatabase({
    required this.dialect,
    required this.tables,
    this.enums = const <IntrospectedEnum>[],
    this.routines = const <IntrospectedRoutine>[],
  });

  factory IntrospectedDatabase.fromJson(Map<String, Object?> json) {
    return IntrospectedDatabase(
      dialect: SqlCodegenDialect.values.byName(json['dialect']! as String),
      tables: [
        for (final table in json['tables']! as List<Object?>)
          IntrospectedTable.fromJson(table! as Map<String, Object?>),
      ],
      enums: [
        for (final value in json['enums'] as List<Object?>? ?? const [])
          IntrospectedEnum.fromJson(value! as Map<String, Object?>),
      ],
      routines: [
        for (final routine in json['routines'] as List<Object?>? ?? const [])
          IntrospectedRoutine.fromJson(routine! as Map<String, Object?>),
      ],
    );
  }

  /// Dialect the schema came from.
  final SqlCodegenDialect dialect;

  /// Introspected tables.
  final List<IntrospectedTable> tables;

  /// Introspected database enum types.
  final List<IntrospectedEnum> enums;

  /// Introspected database routines.
  final List<IntrospectedRoutine> routines;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'dialect': dialect.name,
      'tables': [for (final table in tables) table.toJson()],
      if (enums.isNotEmpty)
        'enums': [for (final value in enums) value.toJson()],
      if (routines.isNotEmpty)
        'routines': [for (final routine in routines) routine.toJson()],
    };
  }
}

/// Introspected enum type description.
final class IntrospectedEnum {
  const IntrospectedEnum({
    required this.name,
    required this.values,
    this.schema,
  });

  factory IntrospectedEnum.fromJson(Map<String, Object?> json) {
    return IntrospectedEnum(
      name: json['name']! as String,
      schema: json['schema'] as String?,
      values: [
        for (final value in json['values']! as List<Object?>) value! as String,
      ],
    );
  }

  /// Enum type name without schema qualification.
  final String name;

  /// Optional schema name.
  final String? schema;

  /// Database labels in declaration order.
  final List<String> values;

  Map<String, Object?> toJson() {
    return <String, Object?>{'name': name, 'schema': ?schema, 'values': values};
  }
}

/// Introspected table description.
final class IntrospectedTable {
  const IntrospectedTable({
    required this.name,
    required this.columns,
    this.schema,
    this.constraints = const <IntrospectedTableConstraint>[],
  });

  factory IntrospectedTable.fromJson(Map<String, Object?> json) {
    return IntrospectedTable(
      name: json['name']! as String,
      schema: json['schema'] as String?,
      columns: [
        for (final column in json['columns']! as List<Object?>)
          IntrospectedColumn.fromJson(column! as Map<String, Object?>),
      ],
      constraints: [
        for (final constraint
            in json['constraints'] as List<Object?>? ?? const [])
          IntrospectedTableConstraint.fromJson(
            constraint! as Map<String, Object?>,
          ),
      ],
    );
  }

  /// Table name without schema qualification.
  final String name;

  /// Optional schema name.
  final String? schema;

  /// Columns that belong to the table.
  final List<IntrospectedColumn> columns;

  /// Constraints declared on this table.
  final List<IntrospectedTableConstraint> constraints;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'schema': ?schema,
      'columns': [for (final column in columns) column.toJson()],
      if (constraints.isNotEmpty)
        'constraints': [
          for (final constraint in constraints) constraint.toJson(),
        ],
    };
  }
}

/// Table-level constraint description.
final class IntrospectedTableConstraint {
  const IntrospectedTableConstraint({
    required this.name,
    required this.kind,
    this.columns = const <String>[],
    this.referencedSchema,
    this.referencedTable,
    this.referencedColumns = const <String>[],
    this.expression,
  });

  factory IntrospectedTableConstraint.fromJson(Map<String, Object?> json) {
    return IntrospectedTableConstraint(
      name: json['name']! as String,
      kind: IntrospectedTableConstraintKind.values.byName(
        json['kind']! as String,
      ),
      columns: [
        for (final column in json['columns'] as List<Object?>? ?? const [])
          column! as String,
      ],
      referencedSchema: json['referencedSchema'] as String?,
      referencedTable: json['referencedTable'] as String?,
      referencedColumns: [
        for (final column
            in json['referencedColumns'] as List<Object?>? ?? const [])
          column! as String,
      ],
      expression: json['expression'] as String?,
    );
  }

  /// Constraint name.
  final String name;

  /// Constraint kind.
  final IntrospectedTableConstraintKind kind;

  /// Local table columns participating in the constraint.
  final List<String> columns;

  /// Referenced schema for foreign keys.
  final String? referencedSchema;

  /// Referenced table for foreign keys.
  final String? referencedTable;

  /// Referenced columns for foreign keys.
  final List<String> referencedColumns;

  /// Check expression, when available.
  final String? expression;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'kind': kind.name,
      if (columns.isNotEmpty) 'columns': columns,
      'referencedSchema': ?referencedSchema,
      'referencedTable': ?referencedTable,
      if (referencedColumns.isNotEmpty) 'referencedColumns': referencedColumns,
      'expression': ?expression,
    };
  }
}

/// Supported table constraint kinds.
enum IntrospectedTableConstraintKind { primaryKey, unique, foreignKey, check }

/// Introspected column description.
final class IntrospectedColumn {
  const IntrospectedColumn({
    required this.name,
    required this.databaseType,
    required this.dartType,
    this.nullable = false,
    this.hasDefault = false,
    this.defaultExpression,
    this.primaryKey = false,
    this.enumName,
    this.enumSchema,
    this.enumValues = const <String>[],
    this.constrainedValues = const <String>[],
    this.extensionBaseDartType,
  });

  factory IntrospectedColumn.fromJson(Map<String, Object?> json) {
    return IntrospectedColumn(
      name: json['name']! as String,
      databaseType: json['databaseType']! as String,
      dartType: json['dartType']! as String,
      nullable: json['nullable'] as bool? ?? false,
      hasDefault: json['hasDefault'] as bool? ?? false,
      defaultExpression: json['defaultExpression'] as String?,
      primaryKey: json['primaryKey'] as bool? ?? false,
      enumName: json['enumName'] as String?,
      enumSchema: json['enumSchema'] as String?,
      enumValues: [
        for (final value in json['enumValues'] as List<Object?>? ?? const [])
          value! as String,
      ],
      constrainedValues: [
        for (final value
            in json['constrainedValues'] as List<Object?>? ?? const [])
          value! as String,
      ],
      extensionBaseDartType: json['extensionBaseDartType'] as String?,
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

  /// Database default expression, when introspected.
  final String? defaultExpression;

  /// Whether the column is part of the primary key.
  final bool primaryKey;

  /// Enum type name when this column uses a database enum.
  final String? enumName;

  /// Enum type schema when this column uses a database enum.
  final String? enumSchema;

  /// Enum values when this column uses a database enum.
  final List<String> enumValues;

  /// Allowed text values from a simple single-column check constraint.
  final List<String> constrainedValues;

  /// Primitive Dart type wrapped by a generated extension type, when this
  /// column was codegen-normalized to a value object.
  final String? extensionBaseDartType;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'databaseType': databaseType,
      'dartType': dartType,
      if (nullable) 'nullable': true,
      if (hasDefault) 'hasDefault': true,
      'defaultExpression': ?defaultExpression,
      if (primaryKey) 'primaryKey': true,
      'enumName': ?enumName,
      'enumSchema': ?enumSchema,
      if (enumValues.isNotEmpty) 'enumValues': enumValues,
      if (constrainedValues.isNotEmpty) 'constrainedValues': constrainedValues,
      'extensionBaseDartType': ?extensionBaseDartType,
    };
  }
}

/// Introspected routine description.
final class IntrospectedRoutine {
  const IntrospectedRoutine({
    required this.name,
    required this.schema,
    required this.kind,
    required this.returnDatabaseType,
    required this.returnDartType,
    this.returnsSet = false,
    this.parameters = const <IntrospectedRoutineParameter>[],
  });

  factory IntrospectedRoutine.fromJson(Map<String, Object?> json) {
    return IntrospectedRoutine(
      name: json['name']! as String,
      schema: json['schema'] as String?,
      kind: IntrospectedRoutineKind.values.byName(json['kind']! as String),
      returnDatabaseType: json['returnDatabaseType']! as String,
      returnDartType: json['returnDartType']! as String,
      returnsSet: json['returnsSet'] as bool? ?? false,
      parameters: [
        for (final parameter
            in json['parameters'] as List<Object?>? ?? const [])
          IntrospectedRoutineParameter.fromJson(
            parameter! as Map<String, Object?>,
          ),
      ],
    );
  }

  /// Routine name without schema qualification.
  final String name;

  /// Optional schema name.
  final String? schema;

  /// Whether the routine is a function or procedure.
  final IntrospectedRoutineKind kind;

  /// Database-native return type string.
  final String returnDatabaseType;

  /// Dart type string chosen for generated source.
  final String returnDartType;

  /// Whether the function returns a set of values.
  final bool returnsSet;

  /// Input parameters accepted by the routine.
  final List<IntrospectedRoutineParameter> parameters;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'schema': ?schema,
      'kind': kind.name,
      'returnDatabaseType': returnDatabaseType,
      'returnDartType': returnDartType,
      if (returnsSet) 'returnsSet': true,
      if (parameters.isNotEmpty)
        'parameters': [for (final parameter in parameters) parameter.toJson()],
    };
  }
}

/// Routine kind.
enum IntrospectedRoutineKind { function, procedure }

/// Introspected routine input parameter.
final class IntrospectedRoutineParameter {
  const IntrospectedRoutineParameter({
    required this.name,
    required this.databaseType,
    required this.dartType,
  });

  factory IntrospectedRoutineParameter.fromJson(Map<String, Object?> json) {
    return IntrospectedRoutineParameter(
      name: json['name']! as String,
      databaseType: json['databaseType']! as String,
      dartType: json['dartType']! as String,
    );
  }

  /// Parameter name.
  final String name;

  /// Database-native type string.
  final String databaseType;

  /// Dart type string chosen for generated source.
  final String dartType;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'databaseType': databaseType,
      'dartType': dartType,
    };
  }
}
