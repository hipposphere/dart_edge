import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

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

/// Emits a single generated Dart library suitable for build_runner outputs.
String emitDartSchemaLibrary(
  IntrospectedDatabase database, {
  String databaseClassName = 'GeneratedDatabaseSchema',
}) {
  final schemaGroups = _groupTablesBySchema(database.tables);
  final library = Library((builder) {
    builder
      ..comments.add('GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..directives.add(
        Directive.import('package:dart_edge_sql/dart_edge_sql.dart'),
      )
      ..body.add(_databaseClass(databaseClassName, schemaGroups))
      ..body.addAll(schemaGroups.map(_schemaClass));

    for (final group in schemaGroups) {
      for (final table in group.tables) {
        builder.body.addAll(_tableSpecs(table));
      }
    }
  });
  return _format(library);
}

String _emitEntrypoint({
  required String databaseClassName,
  required List<_SchemaGroup> schemaGroups,
}) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..body.add(_databaseClass(databaseClassName, schemaGroups));

    for (final group in schemaGroups) {
      builder.directives.add(
        Directive.import('schemas/${group.folderName}/schema.dart'),
      );
    }
  });
  return _format(library);
}

String _emitSchemaLibrary(_SchemaGroup group) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..body.add(_schemaClass(group));

    for (final table in group.tables) {
      builder.directives.add(
        Directive.import('tables/${_tableFileName(table)}'),
      );
    }
  });
  return _format(library);
}

String _emitTableLibrary(IntrospectedTable table) {
  final library = Library((builder) {
    builder
      ..directives.add(
        Directive.import(
          'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        ),
      )
      ..directives.add(
        Directive.import('package:dart_edge_sql/dart_edge_sql.dart'),
      )
      ..body.addAll(_tableSpecs(table));
  });
  return _format(library);
}

Class _databaseClass(
  String databaseClassName,
  List<_SchemaGroup> schemaGroups,
) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = databaseClassName
      ..constructors.add(_privateConstConstructor())
      ..fields.addAll([
        for (final group in schemaGroups)
          _staticConstField(
            name: group.memberName,
            assignment: refer(group.className).property('instance'),
          ),
        _staticConstField(
          name: 'schemas',
          type: _listOf(refer('JsonSchema')),
          assignment: literalList([
            for (final group in schemaGroups)
              refer(group.className).property('schemas').spread,
          ], refer('JsonSchema')),
        ),
        _staticConstField(
          name: 'jsonSchemas',
          type: refer('JsonSchemaRegistry'),
          assignment: refer(
            'JsonSchemaRegistry',
          ).constInstance(const <Expression>[], {'schemas': refer('schemas')}),
        ),
      ]);
  });
}

Class _schemaClass(_SchemaGroup group) {
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = group.className
      ..constructors.add(_privateConstConstructor())
      ..fields.addAll([
        _staticConstField(
          name: 'instance',
          assignment: refer(group.className).constInstanceNamed('_', const []),
        ),
        _staticConstField(
          name: 'schemaName',
          assignment: literalString(group.schemaName),
        ),
        for (final table in group.tables)
          _staticConstField(
            name: _schemaTableMemberName(table.name),
            assignment: refer(
              '${_upperCamel(table.name)}Table',
            ).property('table'),
          ),
        _staticConstField(
          name: 'schemas',
          type: _listOf(refer('JsonSchema')),
          assignment: literalList([
            for (final table in group.tables) ...[
              refer('${_upperCamel(table.name)}Row').property('jsonSchema'),
              refer('${_upperCamel(table.name)}Insert').property('jsonSchema'),
              refer('${_upperCamel(table.name)}Update').property('jsonSchema'),
            ],
          ], refer('JsonSchema')),
        ),
        _staticConstField(
          name: 'jsonSchemas',
          type: refer('JsonSchemaRegistry'),
          assignment: refer(
            'JsonSchemaRegistry',
          ).constInstance(const <Expression>[], {'schemas': refer('schemas')}),
        ),
      ]);
  });
}

Iterable<Spec> _tableSpecs(IntrospectedTable table) sync* {
  yield _rowClass(table);
  yield _insertClass(table);
  yield _updateClass(table);
  yield _tableClass(table);
}

Class _rowClass(IntrospectedTable table) {
  final rowType = '${_upperCamel(table.name)}Row';
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = rowType
      ..implements.add(refer('JsonEncodable'))
      ..constructors.add(
        _fieldConstructor(
          table.columns.map(
            (column) =>
                _fieldParameter(_lowerCamel(column.name), required: true),
          ),
        ),
      )
      ..fields.addAll([
        ..._schemaFields(
          className: rowType,
          table: table,
          shape: _GeneratedShape.row,
        ),
        for (final column in table.columns)
          _instanceFinalField(_lowerCamel(column.name), _fieldType(column)),
      ])
      ..constructors.addAll([
        _fromSqlRowFactory(rowType, table),
        _fromColumnsFactory(rowType),
        _fromJsonFactory(rowType, table, _GeneratedShape.row),
      ])
      ..methods.addAll([
        _mapMethod(
          name: 'toColumns',
          entries: [
            for (final column in table.columns)
              _MapEntrySpec(
                key: column.name,
                value: refer(_lowerCamel(column.name)),
              ),
          ],
        ),
        _mapMethod(
          name: 'toJson',
          annotations: [refer('override')],
          entries: [
            for (final column in table.columns)
              _MapEntrySpec(
                key: column.name,
                value: _toJsonExpression(
                  column,
                  source: refer(_lowerCamel(column.name)),
                ),
              ),
          ],
        ),
        _toStringMethod(rowType, table.columns.map((c) => _lowerCamel(c.name))),
      ]);
  });
}

Class _insertClass(IntrospectedTable table) {
  final insertType = '${_upperCamel(table.name)}Insert';
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = insertType
      ..implements.add(refer('JsonEncodable'))
      ..constructors.add(
        _fieldConstructor(
          table.columns.map((column) {
            final fieldName = _lowerCamel(column.name);
            return _fieldParameter(
              fieldName,
              required: !_isOptionalInsertColumn(column),
              defaultTo: _isOptionalInsertColumn(column)
                  ? refer(
                      'SqlValue',
                    ).constInstanceNamed('absent', const []).code
                  : null,
            );
          }),
        ),
      )
      ..fields.addAll([
        ..._schemaFields(
          className: insertType,
          table: table,
          shape: _GeneratedShape.insert,
        ),
        for (final column in table.columns)
          _instanceFinalField(
            _lowerCamel(column.name),
            _insertFieldType(column),
          ),
      ])
      ..constructors.add(
        _fromJsonFactory(insertType, table, _GeneratedShape.insert),
      )
      ..methods.addAll([
        _mapMethod(
          name: 'toColumns',
          entries: [
            for (final column in table.columns) _insertMapEntry(column),
          ],
        ),
        _mapMethod(
          name: 'toJson',
          annotations: [refer('override')],
          entries: [
            for (final column in table.columns)
              _insertMapEntry(column, encodeJson: true),
          ],
        ),
        _toStringMethod(
          insertType,
          table.columns.map((c) => _lowerCamel(c.name)),
        ),
      ]);
  });
}

Class _updateClass(IntrospectedTable table) {
  final updateType = '${_upperCamel(table.name)}Update';
  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = updateType
      ..implements.add(refer('JsonEncodable'))
      ..constructors.add(
        _fieldConstructor(
          table.columns.map(
            (column) => _fieldParameter(
              _lowerCamel(column.name),
              defaultTo: refer(
                'SqlValue',
              ).constInstanceNamed('absent', const []).code,
            ),
          ),
        ),
      )
      ..fields.addAll([
        ..._schemaFields(
          className: updateType,
          table: table,
          shape: _GeneratedShape.update,
        ),
        for (final column in table.columns)
          _instanceFinalField(
            _lowerCamel(column.name),
            _updateFieldType(column),
          ),
      ])
      ..constructors.add(
        _fromJsonFactory(updateType, table, _GeneratedShape.update),
      )
      ..methods.addAll([
        _mapMethod(
          name: 'toColumns',
          entries: [
            for (final column in table.columns) _updateMapEntry(column),
          ],
        ),
        _mapMethod(
          name: 'toJson',
          annotations: [refer('override')],
          entries: [
            for (final column in table.columns)
              _updateMapEntry(column, encodeJson: true),
          ],
        ),
        _toStringMethod(
          updateType,
          table.columns.map((c) => _lowerCamel(c.name)),
        ),
      ]);
  });
}

Class _tableClass(IntrospectedTable table) {
  final baseName = _upperCamel(table.name);
  final rowType = '${baseName}Row';
  final insertType = '${baseName}Insert';
  final updateType = '${baseName}Update';
  final tableClassName = '${baseName}Table';

  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = tableClassName
      ..extend = _type('SqlTable', [
        refer(rowType),
        refer(insertType),
        refer(updateType),
      ])
      ..constructors.add(_privateConstConstructor())
      ..fields.addAll([
        _staticConstField(
          name: 'table',
          assignment: refer(tableClassName).constInstanceNamed('_', const []),
        ),
        for (final column in table.columns)
          Field((field) {
            field
              ..static = true
              ..modifier = FieldModifier.final$
              ..name = _columnFieldName(column.name)
              ..assignment =
                  _type('SqlColumn', [
                    refer(_normalizedValueType(column)),
                  ]).newInstance(const <Expression>[], {
                    'table': refer('table'),
                    'name': literalString(column.name),
                    'nullable': literalBool(column.nullable),
                  }).code;
          }),
      ])
      ..methods.addAll([
        _getter('name', refer('String'), literalString(table.name)),
        _getter(
          'schema',
          refer('String?'),
          table.schema == null ? literalNull : literalString(table.schema!),
        ),
        _getter(
          'columns',
          _listOf(_type('SqlColumn', [refer('Object?')])),
          literalList([
            for (final column in table.columns)
              refer(_columnFieldName(column.name)).property('asObjectColumn'),
          ], _type('SqlColumn', [refer('Object?')])),
        ),
        Method((method) {
          method
            ..annotations.add(refer('override'))
            ..returns = refer(rowType)
            ..name = 'mapRow'
            ..requiredParameters.add(_typedParameter('row', refer('SqlRow')))
            ..optionalParameters.add(
              _namedParameter(
                'prefix',
                type: refer('String'),
                defaultTo: literalString('').code,
              ),
            )
            ..lambda = true
            ..body = refer(rowType)
                .newInstanceNamed(
                  'fromSqlRow',
                  [refer('row')],
                  {'prefix': refer('prefix')},
                )
                .code;
        }),
        _encodeMethod('encodeInsert', insertType),
        _encodeMethod('encodeUpdate', updateType),
      ]);
  });
}

List<Field> _schemaFields({
  required String className,
  required IntrospectedTable table,
  required _GeneratedShape shape,
}) {
  return <Field>[
    _staticConstField(
      name: 'schemaRef',
      assignment: refer('JsonSchemaRef').constInstance(
        [literalString(className)],
        const <String, Expression>{},
        [refer(className)],
      ),
    ),
    _staticConstField(
      name: 'jsonSchema',
      assignment: _jsonSchemaForTable(table, shape, refer('schemaRef')),
    ),
  ];
}

Expression _jsonSchemaForTable(
  IntrospectedTable table,
  _GeneratedShape shape,
  Expression ref,
) {
  return refer(
    'JsonSchema',
  ).constInstanceNamed('object', const <Expression>[], {
    'ref': ref,
    'properties': literalConstMap(
      {
        for (final column in table.columns)
          literalString(column.name): _jsonSchemaForColumn(column),
      },
      refer('String'),
      refer('JsonSchema'),
    ),
    'required': literalConstList(
      _requiredColumns(table, shape).map(literalString).toList(growable: false),
      refer('String'),
    ),
    'additionalProperties': literalBool(false),
  });
}

Constructor _fromSqlRowFactory(String rowType, IntrospectedTable table) {
  return Constructor((constructor) {
    constructor
      ..factory = true
      ..name = 'fromSqlRow'
      ..requiredParameters.add(_typedParameter('row', refer('SqlRow')))
      ..optionalParameters.add(
        _namedParameter(
          'prefix',
          type: refer('String'),
          defaultTo: literalString('').code,
        ),
      )
      ..lambda = true
      ..body = refer(rowType).newInstance(const <Expression>[], {
        for (final column in table.columns)
          _lowerCamel(column.name): _rowReadExpression(column),
      }).code;
  });
}

Constructor _fromColumnsFactory(String rowType) {
  return Constructor((constructor) {
    constructor
      ..factory = true
      ..name = 'fromColumns'
      ..requiredParameters.add(
        _typedParameter('columns', _mapOf(refer('String'), refer('Object?'))),
      )
      ..optionalParameters.add(
        _namedParameter(
          'prefix',
          type: refer('String'),
          defaultTo: literalString('').code,
        ),
      )
      ..lambda = true
      ..body = refer(rowType)
          .newInstanceNamed(
            'fromSqlRow',
            [
              refer('SqlRow').newInstance([refer('columns')]),
            ],
            {'prefix': refer('prefix')},
          )
          .code;
  });
}

Constructor _fromJsonFactory(
  String typeName,
  IntrospectedTable table,
  _GeneratedShape shape,
) {
  return Constructor((constructor) {
    constructor
      ..factory = true
      ..name = 'fromJson'
      ..requiredParameters.add(
        _typedParameter('json', _mapOf(refer('String'), refer('Object?'))),
      )
      ..lambda = true
      ..body = refer(typeName).newInstance(const <Expression>[], {
        for (final column in table.columns)
          _lowerCamel(column.name): switch (shape) {
            _GeneratedShape.row => _fromJsonExpression(
              column,
              source: _jsonLookup(column.name),
              nullable: column.nullable,
            ),
            _GeneratedShape.insert => _sqlValueFromJsonExpression(
              column,
              optional: _isOptionalInsertColumn(column),
            ),
            _GeneratedShape.update => _sqlValueFromJsonExpression(
              column,
              optional: true,
            ),
          },
      }).code;
  });
}

Expression _rowReadExpression(IntrospectedColumn column) {
  final fieldKey = '\${prefix}${column.name}';
  final type = _normalizedValueType(column);
  if (type == 'Object?') {
    return refer('row')
        .property('read')
        .call(
          [literalString(fieldKey)],
          const <String, Expression>{},
          [refer('Object?')],
        );
  }
  if (column.nullable) {
    return refer('row')
        .property('readNullable')
        .call(
          [literalString(fieldKey)],
          const <String, Expression>{},
          [refer(type)],
        );
  }
  return refer('row')
      .property('read')
      .call(
        [literalString(fieldKey)],
        const <String, Expression>{},
        [refer(type)],
      );
}

Expression _sqlValueFromJsonExpression(
  IntrospectedColumn column, {
  required bool optional,
}) {
  final key = column.name;
  final valueType = _nullableType(
    _normalizedValueType(column),
    column.nullable,
  );
  final parsed = _fromJsonExpression(
    column,
    source: _jsonLookup(key),
    nullable: column.nullable,
  );
  if (!optional) {
    return parsed;
  }
  return CodeExpression(
    Code(
      "json.containsKey('${_escapeLiteral(key)}') ? "
      '${_typeCode(_type('SqlValue', [refer(valueType)]))}(${_code(parsed)}) : '
      'const SqlValue.absent()',
    ),
  );
}

Expression _fromJsonExpression(
  IntrospectedColumn column, {
  required Expression source,
  required bool nullable,
}) {
  final type = _normalizedValueType(column);

  Expression wrapNullable(Expression expression) {
    if (!nullable) {
      return expression;
    }
    return CodeExpression(
      Code('${_code(source)} == null ? null : ${_code(expression)}'),
    );
  }

  return switch (type) {
    'int' => wrapNullable(
      source.asA(refer('num')).property('toInt').call(const []),
    ),
    'double' => wrapNullable(
      source.asA(refer('num')).property('toDouble').call(const []),
    ),
    'num' => wrapNullable(source.asA(refer('num'))),
    'bool' => wrapNullable(source.asA(refer('bool'))),
    'String' => wrapNullable(source.asA(refer('String'))),
    'DateTime' => wrapNullable(
      refer('DateTime').property('parse').call([source.asA(refer('String'))]),
    ),
    'List<int>' => wrapNullable(
      _type('List', [
        refer('int'),
      ]).newInstanceNamed('from', [source.asA(refer('List'))]),
    ),
    'List<Object?>' => wrapNullable(
      _type('List', [
        refer('Object?'),
      ]).newInstanceNamed('from', [source.asA(refer('List'))]),
    ),
    'Object?' => source,
    _ => wrapNullable(source.asA(refer(type))),
  };
}

Expression _toJsonExpression(
  IntrospectedColumn column, {
  required Expression source,
}) {
  final type = _normalizedValueType(column);

  Expression wrapNullable(Expression expression) {
    if (!column.nullable) {
      return expression;
    }
    return CodeExpression(
      Code('${_code(source)} == null ? null : ${_code(expression)}'),
    );
  }

  return switch (type) {
    'DateTime' => wrapNullable(
      source.property('toIso8601String').call(const []),
    ),
    'List<int>' => wrapNullable(
      _type('List', [refer('int')]).newInstanceNamed('from', [source]),
    ),
    'List<Object?>' => wrapNullable(
      _type('List', [refer('Object?')]).newInstanceNamed('from', [source]),
    ),
    _ => source,
  };
}

Expression _jsonSchemaForColumn(IntrospectedColumn column) {
  final type = _normalizedValueType(column);

  if (type == 'Object?') {
    return refer('JsonSchema').constInstanceNamed('any', const []);
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
      items: refer('JsonSchema').constInstanceNamed('integer', const []),
    ),
    'List<Object?>' => _jsonSchemaFactory(
      'array',
      nullable: column.nullable,
      items: refer('JsonSchema').constInstanceNamed('any', const []),
    ),
    _ => _jsonSchemaFactory('string', nullable: column.nullable),
  };
}

Expression _jsonSchemaFactory(
  String kind, {
  required bool nullable,
  String? format,
  Expression? items,
}) {
  return refer('JsonSchema').constInstanceNamed(kind, const <Expression>[], {
    if (nullable) 'nullable': literalBool(true),
    if (format case final format?) 'format': literalString(format),
    if (items case final items?) 'items': items,
  });
}

Method _mapMethod({
  required String name,
  required Iterable<_MapEntrySpec> entries,
  Iterable<Expression> annotations = const [],
}) {
  return Method((method) {
    method
      ..annotations.addAll(annotations)
      ..returns = _mapOf(refer('String'), refer('Object?'))
      ..name = name
      ..lambda = true
      ..body = _mapExpression(entries).code;
  });
}

Expression _mapExpression(Iterable<_MapEntrySpec> entries) {
  final rendered = entries.map((entry) {
    final condition = entry.condition;
    final prefix = condition == null ? '' : 'if (${_code(condition)}) ';
    return "$prefix'${_escapeLiteral(entry.key)}': ${_code(entry.value)},";
  }).join();
  return CodeExpression(Code('<String, Object?>{$rendered}'));
}

_MapEntrySpec _insertMapEntry(
  IntrospectedColumn column, {
  bool encodeJson = false,
}) {
  final fieldName = _lowerCamel(column.name);
  final isOptional = _isOptionalInsertColumn(column);
  final source = isOptional
      ? refer(fieldName).property('value')
      : refer(fieldName);
  return _MapEntrySpec(
    key: column.name,
    value: encodeJson ? _toJsonExpression(column, source: source) : source,
    condition: isOptional ? refer(fieldName).property('isPresent') : null,
  );
}

_MapEntrySpec _updateMapEntry(
  IntrospectedColumn column, {
  bool encodeJson = false,
}) {
  final fieldName = _lowerCamel(column.name);
  final source = refer(fieldName).property('value');
  return _MapEntrySpec(
    key: column.name,
    value: encodeJson ? _toJsonExpression(column, source: source) : source,
    condition: refer(fieldName).property('isPresent'),
  );
}

Method _toStringMethod(String className, Iterable<String> fieldNames) {
  final description = fieldNames.map((name) => '$name: \$$name').join(', ');
  return Method((method) {
    method
      ..annotations.add(refer('override'))
      ..returns = refer('String')
      ..name = 'toString'
      ..lambda = true
      ..body = Code("'$className($description)'");
  });
}

Method _getter(String name, Reference returns, Expression body) {
  return Method((method) {
    method
      ..annotations.add(refer('override'))
      ..type = MethodType.getter
      ..returns = returns
      ..name = name
      ..lambda = true
      ..body = body.code;
  });
}

Method _encodeMethod(String name, String valueType) {
  return Method((method) {
    method
      ..annotations.add(refer('override'))
      ..returns = _mapOf(refer('String'), refer('Object?'))
      ..name = name
      ..requiredParameters.add(_typedParameter('value', refer(valueType)))
      ..lambda = true
      ..body = refer('value').property('toColumns').call(const []).code;
  });
}

Constructor _fieldConstructor(Iterable<Parameter> parameters) {
  return Constructor((constructor) {
    constructor
      ..constant = true
      ..optionalParameters.addAll(parameters);
  });
}

Constructor _privateConstConstructor() {
  return Constructor((constructor) {
    constructor
      ..constant = true
      ..name = '_';
  });
}

Field _staticConstField({
  required String name,
  Reference? type,
  required Expression assignment,
}) {
  return Field((field) {
    field
      ..static = true
      ..modifier = FieldModifier.constant
      ..type = type
      ..name = name
      ..assignment = assignment.code;
  });
}

Field _instanceFinalField(String name, Reference type) {
  return Field((field) {
    field
      ..modifier = FieldModifier.final$
      ..type = type
      ..name = name;
  });
}

Parameter _fieldParameter(
  String name, {
  bool required = false,
  Code? defaultTo,
}) {
  return Parameter((parameter) {
    parameter
      ..name = name
      ..named = true
      ..toThis = true
      ..required = required
      ..defaultTo = defaultTo;
  });
}

Parameter _typedParameter(String name, Reference type) {
  return Parameter((parameter) {
    parameter
      ..name = name
      ..type = type;
  });
}

Parameter _namedParameter(String name, {Reference? type, Code? defaultTo}) {
  return Parameter((parameter) {
    parameter
      ..name = name
      ..named = true
      ..type = type
      ..defaultTo = defaultTo;
  });
}

Expression _jsonLookup(String key) {
  return CodeExpression(Code("json['${_escapeLiteral(key)}']"));
}

String _code(Spec spec) => '${spec.accept(DartEmitter())}';

String _typeCode(Reference reference) => '${reference.accept(DartEmitter())}';

String _format(Library library) {
  return _dartFormatter.format('${library.accept(DartEmitter())}');
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
    '${_fileStem(table.name)}.dart';

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
