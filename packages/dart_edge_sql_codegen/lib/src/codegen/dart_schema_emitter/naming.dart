part of '../dart_schema_emitter.dart';

List<_SchemaGroup> _groupTablesBySchema(Iterable<IntrospectedTable> tables) {
  final grouped = <String, List<IntrospectedTable>>{};
  for (final table in tables) {
    final schemaName = _schemaName(table.schema);
    grouped.putIfAbsent(schemaName, () => <IntrospectedTable>[]).add(table);
  }

  final schemaNames = grouped.keys.toList(growable: false)..sort();
  return <_SchemaGroup>[
    for (final schemaName in schemaNames)
      _SchemaGroup(
        schemaName: schemaName,
        folderName: _schemaFolderName(schemaName),
        className: _schemaClassName(schemaName),
        tables: List<IntrospectedTable>.unmodifiable(
          grouped[schemaName]!
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
  return refer(_nullableType(_normalizedValueType(column), column.nullable));
}

Reference _insertFieldType(IntrospectedColumn column) {
  if (_isOptionalInsertColumn(column)) {
    return _type('SqlValue', [
      refer(_nullableType(_normalizedValueType(column), column.nullable)),
    ]);
  }
  return _fieldType(column);
}

Reference _updateFieldType(IntrospectedColumn column) {
  return _type('SqlValue', [
    refer(_nullableType(_normalizedValueType(column), column.nullable)),
  ]);
}

bool _isOptionalInsertColumn(IntrospectedColumn column) =>
    column.hasDefault || column.primaryKey;

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

final class _SchemaGroup {
  const _SchemaGroup({
    required this.schemaName,
    required this.folderName,
    required this.className,
    required this.tables,
  });

  final String schemaName;
  final String folderName;
  final String className;
  final List<IntrospectedTable> tables;

  String get memberName => _lowerCamel(className);
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
  'schemas',
  'jsonSchemas',
  'schemaName',
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
