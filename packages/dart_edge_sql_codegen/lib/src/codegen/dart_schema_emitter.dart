import '../introspection/introspected_database.dart';

/// Emits Dart source for the introspected [database].
///
/// The generated source includes typed row, insert, and update model classes,
/// `SqlTable` descriptors, and JSON Schema metadata for each table.
String emitDartSchema(
  IntrospectedDatabase database, {
  String libraryName = 'database_schema',
  String databaseClassName = 'GeneratedDatabaseSchema',
}) {
  final buffer = StringBuffer()
    ..writeln('library $libraryName;')
    ..writeln()
    ..writeln("import 'package:dart_edge_sql/dart_edge_sql.dart';")
    ..writeln("import 'package:dart_edge_runtime/dart_edge_runtime.dart';")
    ..writeln()
    ..writeln('final class $databaseClassName {')
    ..writeln('  const $databaseClassName._();')
    ..writeln();

  for (final table in database.tables) {
    final tableClassName = '${_upperCamel(table.name)}Table';
    buffer.writeln(
      '  static const $tableClassName ${_lowerCamel(table.name)} = '
      '$tableClassName.table;',
    );
  }

  buffer
    ..writeln()
    ..writeln('  static const jsonSchemas = JsonSchemaRegistry(')
    ..writeln('    definitions: <JsonSchemaDefinition>[');
  for (final table in database.tables) {
    final baseName = _upperCamel(table.name);
    buffer.writeln('      ${baseName}Row.jsonSchema,');
    buffer.writeln('      ${baseName}Insert.jsonSchema,');
    buffer.writeln('      ${baseName}Update.jsonSchema,');
  }
  buffer
    ..writeln('    ],')
    ..writeln('  );')
    ..writeln('}')
    ..writeln();

  for (final table in database.tables) {
    _emitRowClass(buffer, table);
    _emitInsertClass(buffer, table);
    _emitUpdateClass(buffer, table);
    _emitTableClass(buffer, table);
  }

  return buffer.toString();
}

void _emitRowClass(StringBuffer buffer, IntrospectedTable table) {
  final rowType = '${_upperCamel(table.name)}Row';

  buffer
    ..writeln('final class $rowType implements JsonEncodable {')
    ..writeln('  const $rowType({');
  for (final column in table.columns) {
    buffer.writeln('    required this.${_lowerCamel(column.name)},');
  }
  buffer
    ..writeln('  });')
    ..writeln();

  _writeSchemaConstants(
    buffer,
    className: rowType,
    table: table,
    shape: _GeneratedShape.row,
  );

  buffer..writeln(
    '  factory $rowType.fromSqlRow(SqlRow row, {String prefix = \'\'}) => $rowType(',
  );
  for (final column in table.columns) {
    buffer.writeln(
      '        ${_lowerCamel(column.name)}: ${_rowReadExpression(column)},',
    );
  }
  buffer
    ..writeln('      );')
    ..writeln()
    ..writeln(
      '  factory $rowType.fromColumns(Map<String, Object?> columns, {String prefix = \'\'}) =>',
    )
    ..writeln('      $rowType.fromSqlRow(SqlRow(columns), prefix: prefix);')
    ..writeln()
    ..writeln(
      '  factory $rowType.fromJson(Map<String, Object?> json) => $rowType(',
    );
  for (final column in table.columns) {
    buffer.writeln(
      '        ${_lowerCamel(column.name)}: ${_fromJsonExpression(column, source: "json[\'${_escapeLiteral(column.name)}\']", nullable: column.nullable)},',
    );
  }
  buffer
    ..writeln('      );')
    ..writeln();

  for (final column in table.columns) {
    buffer.writeln(
      '  final ${_fieldType(column)} ${_lowerCamel(column.name)};',
    );
  }

  buffer
    ..writeln()
    ..writeln('  Map<String, Object?> toColumns() => <String, Object?>{');
  for (final column in table.columns) {
    buffer.writeln(
      "        '${_escapeLiteral(column.name)}': ${_lowerCamel(column.name)},",
    );
  }
  buffer
    ..writeln('      };')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Map<String, Object?> toJson() => <String, Object?>{');
  for (final column in table.columns) {
    buffer.writeln(
      "        '${_escapeLiteral(column.name)}': ${_toJsonExpression(column, source: _lowerCamel(column.name))},",
    );
  }
  buffer
    ..writeln('      };')
    ..writeln('}')
    ..writeln();
}

void _emitInsertClass(StringBuffer buffer, IntrospectedTable table) {
  final insertType = '${_upperCamel(table.name)}Insert';

  buffer
    ..writeln('final class $insertType implements JsonEncodable {')
    ..writeln('  const $insertType({');
  for (final column in table.columns) {
    buffer.writeln('    ${_insertConstructorParameter(column)}');
  }
  buffer
    ..writeln('  });')
    ..writeln();

  _writeSchemaConstants(
    buffer,
    className: insertType,
    table: table,
    shape: _GeneratedShape.insert,
  );

  buffer
    ..writeln()
    ..writeln(
      '  factory $insertType.fromJson(Map<String, Object?> json) => $insertType(',
    );
  for (final column in table.columns) {
    buffer.writeln(
      '        ${_lowerCamel(column.name)}: ${_insertFromJsonExpression(column)},',
    );
  }
  buffer
    ..writeln('      );')
    ..writeln();

  for (final column in table.columns) {
    buffer.writeln(
      '  final ${_insertFieldType(column)} ${_lowerCamel(column.name)};',
    );
  }

  buffer
    ..writeln()
    ..writeln('  Map<String, Object?> toColumns() => <String, Object?>{');
  for (final column in table.columns) {
    final fieldName = _lowerCamel(column.name);
    if (_isOptionalInsertColumn(column)) {
      buffer.writeln(
        "        if ($fieldName.isPresent) '${_escapeLiteral(column.name)}': $fieldName.value,",
      );
    } else {
      buffer.writeln("        '${_escapeLiteral(column.name)}': $fieldName,");
    }
  }
  buffer
    ..writeln('      };')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Map<String, Object?> toJson() => <String, Object?>{');
  for (final column in table.columns) {
    final fieldName = _lowerCamel(column.name);
    if (_isOptionalInsertColumn(column)) {
      buffer.writeln(
        "        if ($fieldName.isPresent) '${_escapeLiteral(column.name)}': ${_toJsonExpression(column, source: '$fieldName.value')},",
      );
    } else {
      buffer.writeln(
        "        '${_escapeLiteral(column.name)}': ${_toJsonExpression(column, source: fieldName)},",
      );
    }
  }
  buffer
    ..writeln('      };')
    ..writeln('}')
    ..writeln();
}

void _emitUpdateClass(StringBuffer buffer, IntrospectedTable table) {
  final updateType = '${_upperCamel(table.name)}Update';

  buffer
    ..writeln('final class $updateType implements JsonEncodable {')
    ..writeln('  const $updateType({');
  for (final column in table.columns) {
    buffer.writeln(
      '    this.${_lowerCamel(column.name)} = const SqlValue.absent(),',
    );
  }
  buffer
    ..writeln('  });')
    ..writeln();

  _writeSchemaConstants(
    buffer,
    className: updateType,
    table: table,
    shape: _GeneratedShape.update,
  );

  buffer
    ..writeln()
    ..writeln(
      '  factory $updateType.fromJson(Map<String, Object?> json) => $updateType(',
    );
  for (final column in table.columns) {
    buffer.writeln(
      '        ${_lowerCamel(column.name)}: ${_updateFromJsonExpression(column)},',
    );
  }
  buffer
    ..writeln('      );')
    ..writeln();

  for (final column in table.columns) {
    buffer.writeln(
      '  final ${_updateFieldType(column)} ${_lowerCamel(column.name)};',
    );
  }

  buffer
    ..writeln()
    ..writeln('  Map<String, Object?> toColumns() => <String, Object?>{');
  for (final column in table.columns) {
    final fieldName = _lowerCamel(column.name);
    buffer.writeln(
      "        if ($fieldName.isPresent) '${_escapeLiteral(column.name)}': $fieldName.value,",
    );
  }
  buffer
    ..writeln('      };')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Map<String, Object?> toJson() => <String, Object?>{');
  for (final column in table.columns) {
    final fieldName = _lowerCamel(column.name);
    buffer.writeln(
      "        if ($fieldName.isPresent) '${_escapeLiteral(column.name)}': ${_toJsonExpression(column, source: '$fieldName.value')},",
    );
  }
  buffer
    ..writeln('      };')
    ..writeln('}')
    ..writeln();
}

void _emitTableClass(StringBuffer buffer, IntrospectedTable table) {
  final baseName = _upperCamel(table.name);
  final rowType = '${baseName}Row';
  final insertType = '${baseName}Insert';
  final updateType = '${baseName}Update';
  final tableClassName = '${baseName}Table';

  buffer
    ..writeln(
      'final class $tableClassName extends SqlTable<$rowType, $insertType, $updateType> {',
    )
    ..writeln('  const $tableClassName._();')
    ..writeln()
    ..writeln('  static const table = $tableClassName._();')
    ..writeln();

  for (final column in table.columns) {
    buffer.writeln(
      "  static final ${_lowerCamel(column.name)} = SqlColumn<${_normalizedValueType(column)}>("
      "table: table, name: '${_escapeLiteral(column.name)}', nullable: ${column.nullable});",
    );
  }

  buffer
    ..writeln()
    ..writeln("  @override String get name => '${_escapeLiteral(table.name)}';")
    ..writeln(
      "  @override String? get schema => ${table.schema == null ? 'null' : "'${_escapeLiteral(table.schema!)}'"};",
    )
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  List<SqlColumn<Object?>> get columns => <SqlColumn<Object?>>[',
    );
  for (final column in table.columns) {
    buffer.writeln('        ${_lowerCamel(column.name)}.asObjectColumn,');
  }
  buffer
    ..writeln('      ];')
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  $rowType mapRow(SqlRow row, {String prefix = \'\'}) => $rowType.fromSqlRow(row, prefix: prefix);',
    )
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  Map<String, Object?> encodeInsert($insertType value) => value.toColumns();',
    )
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  Map<String, Object?> encodeUpdate($updateType value) => value.toColumns();',
    )
    ..writeln('}')
    ..writeln();
}

void _writeSchemaConstants(
  StringBuffer buffer, {
  required String className,
  required IntrospectedTable table,
  required _GeneratedShape shape,
}) {
  final requiredColumns = _requiredColumns(table, shape);

  buffer
    ..writeln(
      "  static const schemaRef = JsonSchemaRef<$className>('$className');",
    )
    ..writeln('  static const jsonSchema = JsonSchemaDefinition(')
    ..writeln('    ref: schemaRef,')
    ..writeln('    schema: <String, Object?>{')
    ..writeln("      r'\$id': '$className',")
    ..writeln("      'type': 'object',")
    ..writeln("      'properties': <String, Object?>{");

  for (final column in table.columns) {
    buffer.writeln(
      "        '${_escapeLiteral(column.name)}': ${_jsonSchemaForColumn(column)},",
    );
  }

  buffer.writeln('      },');
  if (requiredColumns.isNotEmpty) {
    buffer.writeln("      'required': <String>[");
    for (final columnName in requiredColumns) {
      buffer.writeln("        '$columnName',");
    }
    buffer.writeln('      ],');
  }
  buffer
    ..writeln("      'additionalProperties': false,")
    ..writeln('    },')
    ..writeln('  );')
    ..writeln();
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

String _rowReadExpression(IntrospectedColumn column) {
  final fieldKey = '\${prefix}${_escapeLiteral(column.name)}';
  final type = _normalizedValueType(column);
  if (type == 'Object?') {
    return "row.read<Object?>('$fieldKey')";
  }
  if (column.nullable) {
    return "row.readNullable<$type>('$fieldKey')";
  }
  return "row.read<$type>('$fieldKey')";
}

String _insertFromJsonExpression(IntrospectedColumn column) {
  final key = _escapeLiteral(column.name);
  final source = "json['$key']";
  if (_isOptionalInsertColumn(column)) {
    return "json.containsKey('$key') ? SqlValue<${_nullableType(_normalizedValueType(column), column.nullable)}>(${_fromJsonExpression(column, source: source, nullable: column.nullable)}) : const SqlValue.absent()";
  }
  return _fromJsonExpression(column, source: source, nullable: column.nullable);
}

String _updateFromJsonExpression(IntrospectedColumn column) {
  final key = _escapeLiteral(column.name);
  final source = "json['$key']";
  return "json.containsKey('$key') ? SqlValue<${_nullableType(_normalizedValueType(column), column.nullable)}>(${_fromJsonExpression(column, source: source, nullable: column.nullable)}) : const SqlValue.absent()";
}

String _fromJsonExpression(
  IntrospectedColumn column, {
  required String source,
  required bool nullable,
}) {
  final type = _normalizedValueType(column);

  String wrapNullable(String expression) =>
      nullable ? '$source == null ? null : $expression' : expression;

  return switch (type) {
    'int' => wrapNullable('($source as num).toInt()'),
    'double' => wrapNullable('($source as num).toDouble()'),
    'num' => wrapNullable('$source as num'),
    'bool' => wrapNullable('$source as bool'),
    'String' => wrapNullable('$source as String'),
    'DateTime' => wrapNullable('DateTime.parse($source as String)'),
    'List<int>' => wrapNullable('List<int>.from($source as List)'),
    'List<Object?>' => wrapNullable('List<Object?>.from($source as List)'),
    'Object?' => source,
    _ => wrapNullable('$source as $type'),
  };
}

String _toJsonExpression(IntrospectedColumn column, {required String source}) {
  final type = _normalizedValueType(column);

  String wrapNullable(String expression) =>
      column.nullable ? '$source == null ? null : $expression' : expression;

  return switch (type) {
    'DateTime' => wrapNullable('$source.toIso8601String()'),
    'List<int>' => wrapNullable('List<int>.from($source)'),
    'List<Object?>' => wrapNullable('List<Object?>.from($source)'),
    _ => source,
  };
}

String _jsonSchemaForColumn(IntrospectedColumn column) {
  final type = _normalizedValueType(column);

  if (type == 'Object?') {
    return '<String, Object?>{}';
  }

  final schemaEntries = <String>[];
  switch (type) {
    case 'int':
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('integer', column.nullable)}",
      );
      break;
    case 'double':
    case 'num':
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('number', column.nullable)}",
      );
      break;
    case 'bool':
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('boolean', column.nullable)}",
      );
      break;
    case 'String':
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('string', column.nullable)}",
      );
      break;
    case 'DateTime':
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('string', column.nullable)}",
      );
      schemaEntries.add("'format': 'date-time'");
      break;
    case 'List<int>':
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('array', column.nullable)}",
      );
      schemaEntries.add("'items': <String, Object?>{'type': 'integer'}");
      break;
    case 'List<Object?>':
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('array', column.nullable)}",
      );
      schemaEntries.add("'items': <String, Object?>{}");
      break;
    default:
      schemaEntries.add(
        "'type': ${_jsonTypeLiteral('string', column.nullable)}",
      );
      break;
  }

  return '<String, Object?>{${schemaEntries.join(', ')}}';
}

String _jsonTypeLiteral(String type, bool nullable) {
  if (!nullable) {
    return "'$type'";
  }
  return '<String>[\'$type\', \'null\']';
}

String _fieldType(IntrospectedColumn column) =>
    _nullableType(_normalizedValueType(column), column.nullable);

String _insertFieldType(IntrospectedColumn column) {
  if (_isOptionalInsertColumn(column)) {
    return 'SqlValue<${_nullableType(_normalizedValueType(column), column.nullable)}>';
  }
  return _fieldType(column);
}

String _updateFieldType(IntrospectedColumn column) =>
    'SqlValue<${_nullableType(_normalizedValueType(column), column.nullable)}>';

String _insertConstructorParameter(IntrospectedColumn column) {
  final fieldName = _lowerCamel(column.name);
  if (_isOptionalInsertColumn(column)) {
    return 'this.$fieldName = const SqlValue.absent(),';
  }
  return 'required this.$fieldName,';
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

String _sanitizeIdentifierPart(String value) {
  final alphanumericOnly = value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
  final normalized = alphanumericOnly.isEmpty ? 'field' : alphanumericOnly;
  if (RegExp(r'^[0-9]').hasMatch(normalized)) {
    return 'n$normalized';
  }
  return normalized;
}

String _escapeLiteral(String value) => value.replaceAll("'", r"\'");

enum _GeneratedShape { row, insert, update }
