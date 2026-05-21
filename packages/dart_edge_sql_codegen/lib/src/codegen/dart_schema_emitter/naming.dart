part of '../dart_schema_emitter.dart';

/// Generated table model kind passed to a [DartSchemaModelNameBuilder].
enum DartSchemaModelKind { row, insert, update, table }

/// Context for choosing a generated table model class name.
final class DartSchemaModelNameContext {
  const DartSchemaModelNameContext({
    required this.schemaName,
    required this.tableName,
    required this.kind,
    required this.defaultName,
  });

  /// SQL schema name, or `null` when the table is not schema-qualified.
  final String? schemaName;

  /// SQL table name before Dart identifier normalization.
  final String tableName;

  /// Generated model shape being named.
  final DartSchemaModelKind kind;

  /// Default generated class name for this model.
  final String defaultName;
}

/// Builds a generated Dart class name for a table model.
typedef DartSchemaModelNameBuilder =
    String Function(DartSchemaModelNameContext context);

/// Naming configuration for generated Dart SQL schema code.
final class DartSchemaNaming {
  const DartSchemaNaming({this.modelNameBuilder});

  /// Default naming for generated SQL models.
  static final defaults = schemaPrefixed;

  /// Naming that preserves the historical generated class names.
  static const unprefixed = DartSchemaNaming();

  /// Naming that prefixes table models with their SQL schema name.
  static final schemaPrefixed = DartSchemaNaming(
    modelNameBuilder: schemaPrefixedModelNameBuilder,
  );

  /// Optional callback that overrides generated table model class names.
  final DartSchemaModelNameBuilder? modelNameBuilder;

  String modelName(DartSchemaModelNameContext context) {
    final builder = modelNameBuilder ?? defaultModelNameBuilder;
    return builder(context);
  }

  /// Returns [DartSchemaModelNameContext.defaultName].
  static String defaultModelNameBuilder(DartSchemaModelNameContext context) {
    return context.defaultName;
  }

  /// Prefixes models with the normalized SQL schema name when one exists.
  static String schemaPrefixedModelNameBuilder(
    DartSchemaModelNameContext context,
  ) {
    final schemaName = context.schemaName?.trim();
    if (schemaName == null || schemaName.isEmpty) {
      return context.defaultName;
    }
    return '${_upperCamel(schemaName)}${context.defaultName}';
  }
}

List<_SchemaGroup> _groupBySchema(IntrospectedDatabase database) {
  final grouped = <String, List<IntrospectedTable>>{};
  for (final table in database.tables) {
    final schemaName = _schemaName(table.schema);
    grouped.putIfAbsent(schemaName, () => <IntrospectedTable>[]).add(table);
  }
  final groupedRoutines = <String, List<IntrospectedRoutine>>{};
  for (final routine in database.routines) {
    final schemaName = _schemaName(routine.schema);
    groupedRoutines
        .putIfAbsent(schemaName, () => <IntrospectedRoutine>[])
        .add(routine);
  }
  final groupedEnums = <String, List<IntrospectedEnum>>{};
  for (final value in database.enums) {
    final schemaName = _schemaName(value.schema);
    groupedEnums.putIfAbsent(schemaName, () => <IntrospectedEnum>[]).add(value);
  }

  final schemaNames = {
    ...grouped.keys,
    ...groupedRoutines.keys,
    ...groupedEnums.keys,
  }.toList()..sort();
  return <_SchemaGroup>[
    for (final schemaName in schemaNames)
      _SchemaGroup(
        schemaName: schemaName,
        folderName: _schemaFolderName(schemaName),
        className: _schemaClassName(schemaName),
        enums: List<IntrospectedEnum>.unmodifiable(
          (groupedEnums[schemaName] ?? <IntrospectedEnum>[])
            ..sort((left, right) => left.name.compareTo(right.name)),
        ),
        tables: List<IntrospectedTable>.unmodifiable(
          (grouped[schemaName] ?? <IntrospectedTable>[])
            ..sort((left, right) => left.name.compareTo(right.name)),
        ),
        routines: List<IntrospectedRoutine>.unmodifiable(
          (groupedRoutines[schemaName] ?? <IntrospectedRoutine>[])
            ..sort((left, right) => left.name.compareTo(right.name)),
        ),
      ),
  ];
}

List<String> _requiredColumns(IntrospectedTable table, _GeneratedShape shape) {
  return switch (shape) {
    _GeneratedShape.row =>
      table.columns.map((column) => column.name).toList(growable: false),
    _GeneratedShape.insert =>
      table.columns
          .where((column) => !_isOptionalInsertColumn(column))
          .map((column) => column.name)
          .toList(growable: false),
    _GeneratedShape.update => const <String>[],
  };
}

Reference _fieldType(IntrospectedColumn column) {
  return refer(_nullableType(_valueType(column), column.nullable));
}

Reference _insertFieldType(IntrospectedColumn column) {
  if (_isOptionalInsertColumn(column)) {
    return _type('SqlValue', [
      refer(_nullableType(_valueType(column), column.nullable)),
    ]);
  }
  return _fieldType(column);
}

Reference _updateFieldType(IntrospectedColumn column) {
  return _type('SqlValue', [
    refer(_nullableType(_valueType(column), column.nullable)),
  ]);
}

Reference _sqlColumnType(IntrospectedColumn column) {
  if (_hasStringBackedValueType(column)) {
    return refer('String');
  }
  return refer(_valueType(column));
}

String _columnDatabaseType(IntrospectedColumn column) {
  if (column.enumName case final enumName?) {
    if (column.enumSchema case final enumSchema?) {
      return '$enumSchema.$enumName';
    }
    return enumName;
  }
  return column.databaseType;
}

bool _isOptionalInsertColumn(IntrospectedColumn column) =>
    column.hasDefault || column.primaryKey;

String _valueType(IntrospectedColumn column) {
  return _normalizedValueType(column);
}

String _databaseValueType(IntrospectedColumn column) {
  return column.extensionBaseDartType ?? _normalizedValueType(column);
}

String _normalizedValueType(IntrospectedColumn column) {
  final typeName = column.dartType;
  if (typeName == 'Object?') {
    return 'Object?';
  }
  if (typeName.endsWith('?')) {
    return typeName.substring(0, typeName.length - 1);
  }
  return typeName;
}

bool _hasStringBackedValueType(IntrospectedColumn column) {
  return column.enumName != null || _isConstrainedTextColumn(column);
}

bool _hasExtensionBackedValueType(IntrospectedColumn column) {
  return column.extensionBaseDartType != null;
}

bool _isConstrainedTextColumn(IntrospectedColumn column) {
  return column.enumName == null &&
      column.constrainedValues.isNotEmpty &&
      _normalizeDatabaseType(column.databaseType) == 'text';
}

String _normalizeDatabaseType(String databaseType) {
  return databaseType
      .trim()
      .split(RegExp(r'\s+'))
      .first
      .toLowerCase()
      .replaceAll(RegExp(r'\(.*\)$'), '');
}

IntrospectedDatabase _withGeneratedConstrainedTextTypes(
  IntrospectedDatabase database,
  DartSchemaNaming naming,
) {
  return IntrospectedDatabase(
    dialect: database.dialect,
    enums: database.enums,
    routines: database.routines,
    tables: [
      for (final table in database.tables)
        IntrospectedTable(
          name: table.name,
          schema: table.schema,
          constraints: table.constraints,
          columns: [
            for (final column in table.columns)
              if (_isConstrainedTextColumn(column))
                _copyColumnWithDartType(
                  column,
                  _constrainedTextTypeName(table, column, naming),
                )
              else
                column,
          ],
        ),
    ],
  );
}

IntrospectedColumn _copyColumnWithDartType(
  IntrospectedColumn column,
  String dartType,
) {
  return IntrospectedColumn(
    name: column.name,
    databaseType: column.databaseType,
    dartType: dartType,
    nullable: column.nullable,
    hasDefault: column.hasDefault,
    defaultExpression: column.defaultExpression,
    primaryKey: column.primaryKey,
    enumName: column.enumName,
    enumSchema: column.enumSchema,
    enumValues: column.enumValues,
    constrainedValues: column.constrainedValues,
    extensionBaseDartType: column.extensionBaseDartType,
  );
}

String _constrainedTextTypeName(
  IntrospectedTable table,
  IntrospectedColumn column,
  DartSchemaNaming naming,
) {
  final tableType = _rowClassName(table, naming);
  final suffix = _upperCamel(column.name);
  final rowSuffix = RegExp(r'Row$').firstMatch(tableType);
  if (rowSuffix == null) {
    return '$tableType$suffix';
  }
  return '${tableType.substring(0, rowSuffix.start)}$suffix';
}

IntrospectedDatabase _withGeneratedPrimaryKeyExtensionTypes(
  IntrospectedDatabase database,
  DartSchemaNaming naming, {
  Map<_ColumnKey, ExternalPrimaryKeySpec> externalPrimaryKeyTypeSpecs =
      const <_ColumnKey, ExternalPrimaryKeySpec>{},
}) {
  final declaredPrimaryKeyTypes = <_ColumnKey, _PrimaryKeyTypeSpec>{};
  for (final table in database.tables) {
    final primaryKeyColumns = table.columns
        .where((column) => column.primaryKey)
        .toList(growable: false);
    if (primaryKeyColumns.length != 1) {
      continue;
    }
    final column = primaryKeyColumns.single;
    declaredPrimaryKeyTypes[_columnKey(
      table,
      column.name,
    )] = _PrimaryKeyTypeSpec(
      typeName: _primaryKeyTypeNameForColumn(table, column, naming),
      baseDartType: _normalizedValueType(column),
    );
  }

  if (declaredPrimaryKeyTypes.isEmpty && externalPrimaryKeyTypeSpecs.isEmpty) {
    return database;
  }

  final foreignKeyReferences = <_ColumnKey, _ColumnKey>{};
  for (final table in database.tables) {
    for (final constraint in table.constraints) {
      if (constraint.kind != IntrospectedTableConstraintKind.foreignKey ||
          constraint.columns.length != 1 ||
          constraint.referencedTable == null ||
          constraint.referencedColumns.length != 1) {
        continue;
      }
      foreignKeyReferences[_columnKey(table, constraint.columns.single)] = (
        schema: _schemaName(constraint.referencedSchema ?? table.schema),
        table: constraint.referencedTable!,
        column: constraint.referencedColumns.single,
      );
    }
  }

  final resolvedPrimaryKeyTypes = <_ColumnKey, _PrimaryKeyTypeSpec>{};
  _PrimaryKeyTypeSpec? resolvePrimaryKeyType(
    _ColumnKey key, [
    Set<_ColumnKey>? seen,
  ]) {
    if (resolvedPrimaryKeyTypes[key] case final resolved?) {
      return resolved;
    }
    final localType = declaredPrimaryKeyTypes[key];
    if (localType == null) {
      return null;
    }
    final active = seen ?? <_ColumnKey>{};
    if (!active.add(key)) {
      return localType;
    }
    final referencedKey = foreignKeyReferences[key];
    final inheritedType = switch (referencedKey) {
      null => null,
      final key =>
        resolvePrimaryKeyType(key, active) ??
            _externalPrimaryKeyType(externalPrimaryKeyTypeSpecs, key),
    };
    active.remove(key);

    final resolvedType = inheritedType ?? localType;
    resolvedPrimaryKeyTypes[key] = resolvedType;
    return resolvedType;
  }

  final primaryKeyTypes = <_ColumnKey, _PrimaryKeyTypeSpec>{};
  for (final key in declaredPrimaryKeyTypes.keys) {
    primaryKeyTypes[key] = resolvePrimaryKeyType(key)!;
  }

  final foreignKeyTypes = <_ColumnKey, _PrimaryKeyTypeSpec>{};
  for (final entry in foreignKeyReferences.entries) {
    final key = entry.key;
    final referencedKey = entry.value;
    final referencedType =
        primaryKeyTypes[referencedKey] ??
        _externalPrimaryKeyType(externalPrimaryKeyTypeSpecs, referencedKey);
    if (referencedType == null) {
      continue;
    }
    foreignKeyTypes[key] = referencedType;
  }

  return IntrospectedDatabase(
    dialect: database.dialect,
    enums: database.enums,
    routines: database.routines,
    tables: [
      for (final table in database.tables)
        IntrospectedTable(
          name: table.name,
          schema: table.schema,
          constraints: table.constraints,
          columns: [
            for (final column in table.columns)
              if (primaryKeyTypes[_columnKey(table, column.name)]
                  case final primaryKeyType?)
                _copyColumnWithExtensionType(column, primaryKeyType)
              else if (foreignKeyTypes[_columnKey(table, column.name)]
                  case final foreignKeyType?)
                _copyColumnWithExtensionType(column, foreignKeyType)
              else
                column,
          ],
        ),
    ],
  );
}

_PrimaryKeyTypeSpec? _externalPrimaryKeyType(
  Map<_ColumnKey, ExternalPrimaryKeySpec> externalPrimaryKeyTypeSpecs,
  _ColumnKey key,
) {
  final spec = externalPrimaryKeyTypeSpecs[key];
  if (spec == null) {
    return null;
  }
  return _PrimaryKeyTypeSpec(
    typeName: spec.typeName,
    baseDartType: spec.baseDartType,
  );
}

IntrospectedColumn _copyColumnWithExtensionType(
  IntrospectedColumn column,
  _PrimaryKeyTypeSpec type,
) {
  return IntrospectedColumn(
    name: column.name,
    databaseType: column.databaseType,
    dartType: type.typeName,
    nullable: column.nullable,
    hasDefault: column.hasDefault,
    defaultExpression: column.defaultExpression,
    primaryKey: column.primaryKey,
    enumName: column.enumName,
    enumSchema: column.enumSchema,
    enumValues: column.enumValues,
    constrainedValues: column.constrainedValues,
    extensionBaseDartType: type.baseDartType,
  );
}

_ColumnKey _columnKey(IntrospectedTable table, String column) {
  return (schema: _schemaName(table.schema), table: table.name, column: column);
}

String _primaryKeyTypeName(IntrospectedTable table, DartSchemaNaming naming) {
  final primaryKeyColumns = table.columns
      .where((column) => column.primaryKey)
      .toList(growable: false);
  if (primaryKeyColumns.length != 1) {
    return '${_singularizeTypeStem(_rowClassStem(table, naming))}Id';
  }
  return _primaryKeyTypeNameForColumn(table, primaryKeyColumns.single, naming);
}

String _primaryKeyTypeNameForColumn(
  IntrospectedTable table,
  IntrospectedColumn column,
  DartSchemaNaming naming,
) {
  return '${_singularizeTypeStem(_rowClassStem(table, naming))}'
      '${_upperCamel(column.name)}';
}

String _rowClassStem(IntrospectedTable table, DartSchemaNaming naming) {
  final rowType = _rowClassName(table, naming);
  final rowSuffix = RegExp(r'Row$').firstMatch(rowType);
  return rowSuffix == null ? rowType : rowType.substring(0, rowSuffix.start);
}

String _singularizeTypeStem(String value) {
  if (value.endsWith('ies') && value.length > 3) {
    return '${value.substring(0, value.length - 3)}y';
  }
  if (value.endsWith('s') && !value.endsWith('ss') && value.length > 1) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

typedef _ColumnKey = ({String schema, String table, String column});

final class _PrimaryKeyTypeSpec {
  const _PrimaryKeyTypeSpec({
    required this.typeName,
    required this.baseDartType,
  });

  final String typeName;
  final String baseDartType;
}

Map<_ColumnKey, ExternalPrimaryKeySpec> _externalPrimaryKeyNames(
  Map<String, ExternalPrimaryKeySpec> externalPrimaryKeys,
) {
  return {
    for (final entry in externalPrimaryKeys.entries)
      _externalPrimaryKey(entry.key): entry.value,
  };
}

_ColumnKey _externalPrimaryKey(String key) {
  final parts = key
      .split('.')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length != 3) {
    throw FormatException(
      'External primary key "$key" must use schema.table.column.',
    );
  }
  return (schema: _schemaName(parts[0]), table: parts[1], column: parts[2]);
}

List<ExternalPrimaryKeySpec> _externalPrimaryKeyTypes(
  Map<_ColumnKey, ExternalPrimaryKeySpec> externalPrimaryKeyTypeSpecs,
) {
  final externalPrimaryKeyTypes = <String, ExternalPrimaryKeySpec>{};
  for (final spec in externalPrimaryKeyTypeSpecs.values) {
    externalPrimaryKeyTypes[spec.typeName] = spec;
  }
  return externalPrimaryKeyTypes.values.toList(growable: false)
    ..sort((left, right) => left.typeName.compareTo(right.typeName));
}

bool _usesExternalPrimaryKeyType(
  IntrospectedTable table,
  Set<String> externalPrimaryKeyTypeNames,
) {
  for (final column in table.columns) {
    if (_hasExtensionBackedValueType(column) &&
        externalPrimaryKeyTypeNames.contains(column.dartType)) {
      return true;
    }
  }
  return false;
}

String _nullableType(String typeName, bool isNullable) {
  if (!isNullable || typeName == 'Object?') {
    return typeName;
  }
  if (typeName.endsWith('?')) {
    return typeName;
  }
  return '$typeName?';
}

TypeReference _type(String symbol, [Iterable<Reference> types = const []]) {
  return TypeReference((builder) {
    builder
      ..symbol = symbol
      ..types.addAll(types);
  });
}

TypeReference _listOf(Reference valueType) => _type('List', [valueType]);

TypeReference _mapOf(Reference keyType, Reference valueType) {
  return _type('Map', [keyType, valueType]);
}

String _schemaName(String? schema) {
  final normalized = schema?.trim();
  if (normalized == null || normalized.isEmpty) {
    return 'default';
  }
  return normalized;
}

String _schemaFolderName(String schemaName) {
  return _fileStem(schemaName);
}

String _tableFileName(IntrospectedTable table) =>
    '${_fileStem(table.name)}.g.dart';

String _routineFileName() => 'routines.g.dart';

String _rowClassName(IntrospectedTable table, DartSchemaNaming naming) {
  return _modelClassName(table, naming, DartSchemaModelKind.row);
}

String _insertClassName(IntrospectedTable table, DartSchemaNaming naming) {
  return _modelClassName(table, naming, DartSchemaModelKind.insert);
}

String _updateClassName(IntrospectedTable table, DartSchemaNaming naming) {
  return _modelClassName(table, naming, DartSchemaModelKind.update);
}

String _tableClassName(IntrospectedTable table, DartSchemaNaming naming) {
  return _modelClassName(table, naming, DartSchemaModelKind.table);
}

String _modelClassName(
  IntrospectedTable table,
  DartSchemaNaming naming,
  DartSchemaModelKind kind,
) {
  final baseName = _upperCamel(table.name);
  final defaultName = switch (kind) {
    DartSchemaModelKind.row => '${baseName}Row',
    DartSchemaModelKind.insert => '${baseName}Insert',
    DartSchemaModelKind.update => '${baseName}Update',
    DartSchemaModelKind.table => '${baseName}Table',
  };
  return naming.modelName(
    DartSchemaModelNameContext(
      schemaName: table.schema,
      tableName: table.name,
      kind: kind,
      defaultName: defaultName,
    ),
  );
}

String _upperCamel(String value) {
  final parts = value
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(_sanitizeIdentifierPart)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'GeneratedTable';
  }

  return parts
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join();
}

String _lowerCamel(String value) {
  final upperCamel = _upperCamel(value);
  return '${upperCamel[0].toLowerCase()}${upperCamel.substring(1)}';
}

String _schemaTableMemberName(String tableName) {
  final memberName = _lowerCamel(tableName);
  return _reservedSchemaMemberNames.contains(memberName)
      ? '${memberName}Table'
      : memberName;
}

String _schemaRoutineMemberName(String routineName) {
  final memberName = _lowerCamel(routineName);
  return _reservedRoutineMemberNames.contains(memberName)
      ? '${memberName}Routine'
      : memberName;
}

String _schemaClassName(String schemaName) {
  final className = '${_upperCamel(_schemaFolderName(schemaName))}Schema';
  return className.endsWith('SchemaSchema')
      ? className.substring(0, className.length - 'Schema'.length)
      : className;
}

String _columnFieldName(String columnName) {
  final fieldName = _lowerCamel(columnName);
  return _reservedTableMemberNames.contains(fieldName)
      ? '${fieldName}Column'
      : fieldName;
}

String _enumClassName(String enumName) => _upperCamel(enumName);

String _enumFileName(IntrospectedEnum value) =>
    '${_fileStem(value.name)}.g.dart';

String _enumValueName(String value) {
  final name = _lowerCamel(value);
  return _reservedEnumValueNames.contains(name) ? '${name}Value' : name;
}

String _sanitizeIdentifierPart(String value) {
  final alphanumericOnly = value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
  final normalized = alphanumericOnly.isEmpty ? 'field' : alphanumericOnly;
  if (RegExp(r'^[0-9]').hasMatch(normalized)) {
    return 'n$normalized';
  }
  return normalized;
}

String _fileStem(String value) {
  final normalized = value
      .trim()
      .replaceAllMapped(
        RegExp(r'([A-Z]+)([A-Z][a-z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toLowerCase();
  return normalized.isEmpty ? 'generated' : normalized;
}

String _escapeLiteral(String value) => value.replaceAll("'", r"\'");

String _escapeSqlIdentifier(String value) => value.replaceAll('"', '""');

final class _SchemaGroup {
  const _SchemaGroup({
    required this.schemaName,
    required this.folderName,
    required this.className,
    required this.enums,
    required this.tables,
    required this.routines,
  });

  final String schemaName;
  final String folderName;
  final String className;
  final List<IntrospectedEnum> enums;
  final List<IntrospectedTable> tables;
  final List<IntrospectedRoutine> routines;

  String get memberName => _lowerCamel(className);

  String get routinesClassName => '${className}Routines';
}

final class _MapEntrySpec {
  const _MapEntrySpec({required this.key, required this.value, this.condition});

  final String key;
  final Expression value;
  final Expression? condition;
}

final class _CopyWithFieldSpec {
  const _CopyWithFieldSpec({
    required this.name,
    required this.parameterType,
    required this.value,
  });

  final String name;
  final Reference parameterType;
  final Expression value;
}

enum _GeneratedShape { row, insert, update }

const _reservedSchemaMemberNames = <String>{
  'instance',
  'routines',
  'schemas',
  'jsonSchemas',
  'schemaName',
};

const _reservedRoutineMemberNames = <String>{
  'parameters',
  'routines',
  'schemaName',
};

const _reservedRoutineParameterNames = <String>{'executor'};

const _reservedEnumValueNames = <String>{
  'index',
  'name',
  'value',
  'values',
  'fromDatabase',
  'toString',
};

const _reservedTableMemberNames = <String>{
  'columns',
  'encodeInsert',
  'encodeUpdate',
  'mapRow',
  'name',
  'schema',
  'table',
};

final _dartFormatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);
