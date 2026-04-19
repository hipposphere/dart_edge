import 'dart:io';

import '../introspection/introspected_database.dart';

/// One generated Dart file in a structured schema emission.
final class DartSchemaEmissionFile {
  const DartSchemaEmissionFile({
    required this.relativePath,
    required this.contents,
  });

  final String relativePath;
  final String contents;
}

/// Structured output tree generated from an introspected database schema.
final class DartSchemaEmission {
  DartSchemaEmission({
    required this.entrypointFileName,
    required Iterable<DartSchemaEmissionFile> files,
    required Iterable<String> directories,
  }) : files = List<DartSchemaEmissionFile>.unmodifiable(files),
       directories = List<String>.unmodifiable(
         directories.toSet().toList(growable: false)..sort(),
       );

  final String entrypointFileName;
  final List<DartSchemaEmissionFile> files;
  final List<String> directories;

  DartSchemaEmissionFile fileAt(String relativePath) {
    for (final file in files) {
      if (file.relativePath == relativePath) {
        return file;
      }
    }
    throw StateError('Generated file "$relativePath" was not found.');
  }

  void writeToDirectory(String outputDirectory) {
    final root = Directory(outputDirectory);
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync(recursive: true);

    for (final directory in directories) {
      Directory('${root.path}/$directory').createSync(recursive: true);
    }

    for (final file in files) {
      final outputFile = File('${root.path}/${file.relativePath}');
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(file.contents);
    }
  }
}

/// Emits a structured Dart source tree for the introspected [database].
///
/// The generated output includes:
/// - one root entrypoint file
/// - one schema file per SQL schema / namespace
/// - one table file per table
/// - typed JSON Schema metadata for every row, insert, and update model
DartSchemaEmission emitDartSchema(
  IntrospectedDatabase database, {
  String databaseClassName = 'GeneratedDatabaseSchema',
}) {
  final schemaGroups = _groupTablesBySchema(database.tables);
  final entrypointFileName = '${_fileStem(databaseClassName)}.dart';
  final files = <DartSchemaEmissionFile>[
    DartSchemaEmissionFile(
      relativePath: entrypointFileName,
      contents: _emitEntrypoint(
        databaseClassName: databaseClassName,
        schemaGroups: schemaGroups,
      ),
    ),
  ];
  final directories = <String>{};

  for (final group in schemaGroups) {
    final schemaFolder = 'schemas/${group.folderName}';
    directories
      ..add(schemaFolder)
      ..add('$schemaFolder/tables')
      ..add('$schemaFolder/enums');

    files.add(
      DartSchemaEmissionFile(
        relativePath: '$schemaFolder/schema.dart',
        contents: _emitSchemaLibrary(group),
      ),
    );

    for (final table in group.tables) {
      files.add(
        DartSchemaEmissionFile(
          relativePath: '$schemaFolder/tables/${_tableFileName(table)}',
          contents: _emitTableLibrary(table),
        ),
      );
    }
  }

  return DartSchemaEmission(
    entrypointFileName: entrypointFileName,
    files: files,
    directories: directories,
  );
}

String _emitEntrypoint({
  required String databaseClassName,
  required List<_SchemaGroup> schemaGroups,
}) {
  final buffer = StringBuffer()
    ..writeln(
      "import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';",
    );

  for (final group in schemaGroups) {
    buffer.writeln("import 'schemas/${group.folderName}/schema.dart';");
  }

  buffer
    ..writeln()
    ..writeln('final class $databaseClassName {')
    ..writeln('  const $databaseClassName._();')
    ..writeln();

  for (final group in schemaGroups) {
    buffer.writeln(
      '  static const ${group.memberName} = ${group.className}.instance;',
    );
  }

  buffer
    ..writeln()
    ..writeln('  static const schemas = <JsonSchema>[');
  for (final group in schemaGroups) {
    buffer.writeln('    ...${group.className}.schemas,');
  }
  buffer
    ..writeln('  ];')
    ..writeln()
    ..writeln('  static const jsonSchemas = JsonSchemaRegistry(')
    ..writeln('    schemas: schemas,')
    ..writeln('  );')
    ..writeln('}');

  return buffer.toString();
}

String _emitSchemaLibrary(_SchemaGroup group) {
  final buffer = StringBuffer()
    ..writeln(
      "import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';",
    );

  for (final table in group.tables) {
    buffer.writeln("import 'tables/${_tableFileName(table)}';");
  }

  buffer
    ..writeln()
    ..writeln('final class ${group.className} {')
    ..writeln('  const ${group.className}._();')
    ..writeln()
    ..writeln('  static const instance = ${group.className}._();')
    ..writeln(
      "  static const schemaName = '${_escapeLiteral(group.schemaName)}';",
    )
    ..writeln();

  for (final table in group.tables) {
    buffer.writeln(
      '  static const ${_schemaTableMemberName(table.name)} = '
      '${_upperCamel(table.name)}Table.table;',
    );
  }

  buffer
    ..writeln()
    ..writeln('  static const schemas = <JsonSchema>[');
  for (final table in group.tables) {
    final baseName = _upperCamel(table.name);
    buffer.writeln('    ${baseName}Row.jsonSchema,');
    buffer.writeln('    ${baseName}Insert.jsonSchema,');
    buffer.writeln('    ${baseName}Update.jsonSchema,');
  }
  buffer
    ..writeln('  ];')
    ..writeln()
    ..writeln('  static const jsonSchemas = JsonSchemaRegistry(')
    ..writeln('    schemas: schemas,')
    ..writeln('  );')
    ..writeln('}');

  return buffer.toString();
}

String _emitTableLibrary(IntrospectedTable table) {
  final buffer = StringBuffer()
    ..writeln(
      "import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';",
    )
    ..writeln("import 'package:dart_edge_sql/dart_edge_sql.dart';")
    ..writeln();

  _emitRowClass(buffer, table);
  _emitInsertClass(buffer, table);
  _emitUpdateClass(buffer, table);
  _emitTableClass(buffer, table);

  return buffer.toString();
}

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
    '${_fileStem(table.name)}.dart';

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
    ..writeln();

  _writeToStringOverride(
    buffer,
    className: rowType,
    fieldNames: [for (final column in table.columns) _lowerCamel(column.name)],
  );

  buffer
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
    ..writeln();

  _writeToStringOverride(
    buffer,
    className: insertType,
    fieldNames: [for (final column in table.columns) _lowerCamel(column.name)],
  );

  buffer
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
    ..writeln();

  _writeToStringOverride(
    buffer,
    className: updateType,
    fieldNames: [for (final column in table.columns) _lowerCamel(column.name)],
  );

  buffer
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
    final columnFieldName = _columnFieldName(column.name);
    buffer.writeln(
      "  static final $columnFieldName = SqlColumn<${_normalizedValueType(column)}>("
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
    buffer.writeln('        ${_columnFieldName(column.name)}.asObjectColumn,');
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
    ..writeln('  static const jsonSchema = JsonSchema.object(')
    ..writeln('    ref: schemaRef,')
    ..writeln('    properties: <String, JsonSchema>{');

  for (final column in table.columns) {
    buffer.writeln(
      "      '${_escapeLiteral(column.name)}': ${_jsonSchemaForColumn(column)},",
    );
  }

  buffer.writeln('    },');
  if (requiredColumns.isNotEmpty) {
    buffer.writeln('    required: <String>[');
    for (final columnName in requiredColumns) {
      buffer.writeln("      '$columnName',");
    }
    buffer.writeln('    ],');
  }
  buffer
    ..writeln('    additionalProperties: false,')
    ..writeln('  );')
    ..writeln();
}

void _writeToStringOverride(
  StringBuffer buffer, {
  required String className,
  required Iterable<String> fieldNames,
}) {
  final members = fieldNames.toList(growable: false);
  final description = members
      .map((fieldName) => '$fieldName: \$$fieldName')
      .join(', ');

  buffer
    ..writeln('  @override')
    ..writeln("  String toString() => '$className($description)';")
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
    return 'JsonSchema.any()';
  }

  return switch (type) {
    'int' => _jsonSchemaFactory('integer', nullable: column.nullable),
    'double' ||
    'num' => _jsonSchemaFactory('number', nullable: column.nullable),
    'bool' => _jsonSchemaFactory('boolean', nullable: column.nullable),
    'String' => _jsonSchemaFactory('string', nullable: column.nullable),
    'DateTime' => _jsonSchemaFactory(
      'string',
      nullable: column.nullable,
      format: 'date-time',
    ),
    'List<int>' => _jsonSchemaFactory(
      'array',
      nullable: column.nullable,
      items: 'JsonSchema.integer()',
    ),
    'List<Object?>' => _jsonSchemaFactory(
      'array',
      nullable: column.nullable,
      items: 'JsonSchema.any()',
    ),
    _ => _jsonSchemaFactory('string', nullable: column.nullable),
  };
}

String _jsonSchemaFactory(
  String kind, {
  required bool nullable,
  String? format,
  String? items,
}) {
  final arguments = <String>[
    if (nullable) 'nullable: true',
    if (format case final format?) "format: '$format'",
    if (items case final items?) 'items: $items',
  ];

  final suffix = arguments.isEmpty ? '' : arguments.join(', ');
  return suffix.isEmpty ? 'JsonSchema.$kind()' : 'JsonSchema.$kind($suffix)';
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
