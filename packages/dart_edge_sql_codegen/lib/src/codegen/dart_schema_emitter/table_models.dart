part of '../dart_schema_emitter.dart';

Iterable<Spec> _tableSpecs(
  IntrospectedTable table,
  DartSchemaNaming naming,
) sync* {
  final emittedExtensionTypes = <String>{};
  for (final column in table.columns.where(
    (column) => _declaresExtensionValueType(table, naming, column),
  )) {
    if (emittedExtensionTypes.add(_valueType(column))) {
      yield _extensionValueTypeSpec(column);
    }
  }
  for (final column in table.columns.where(_isConstrainedTextColumn)) {
    yield _constrainedTextTypeSpec(column);
  }
  yield _rowClass(table, naming);
  yield _insertClass(table, naming);
  yield _updateClass(table, naming);
  yield _tableClass(table, naming);
  yield _tableColumnsExtension(table, naming);
}

Code _extensionValueTypeSpec(IntrospectedColumn column) {
  final typeName = _valueType(column);
  final baseType = _databaseValueType(column);
  return Code('''
extension type const $typeName($baseType value) {}
''');
}

bool _declaresExtensionValueType(
  IntrospectedTable table,
  DartSchemaNaming naming,
  IntrospectedColumn column,
) {
  return column.primaryKey &&
      column.dartType == _primaryKeyTypeName(table, naming) &&
      _hasExtensionBackedValueType(column);
}

Code _constrainedTextTypeSpec(IntrospectedColumn column) {
  final typeName = _normalizedValueType(column);
  final seenValueNames = <String, int>{};
  String valueName(String label) {
    final baseName = _enumValueName(label);
    final count = seenValueNames.update(
      baseName,
      (count) => count + 1,
      ifAbsent: () => 0,
    );
    return count == 0 ? baseName : '$baseName$count';
  }

  final namesByValue = {
    for (final value in column.constrainedValues) value: valueName(value),
  };

  final constants = column.constrainedValues
      .map((value) {
        return 'static const ${namesByValue[value]} = $typeName._('
            "'${_escapeLiteral(value)}'"
            ');';
      })
      .join('\n');
  final values = column.constrainedValues
      .map((value) => namesByValue[value])
      .join(', ');
  final switchCases = column.constrainedValues
      .map((value) => "'${_escapeLiteral(value)}' => ${namesByValue[value]},")
      .join('\n');

  return Code('''
extension type const $typeName._(String value) {
  $constants

  static const values = <$typeName>[$values];

  static $typeName fromDatabase(Object? value) {
    final text = value as String;
    return switch (text) {
      $switchCases
      _ => throw ArgumentError.value(value, 'value', 'Unknown $typeName database value.'),
    };
  }
}
''');
}

Class _rowClass(IntrospectedTable table, DartSchemaNaming naming) {
  final rowType = _rowClassName(table, naming);
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
        _decodeFactory(rowType),
        _fromJsonFactory(rowType, table, _GeneratedShape.row),
      ])
      ..methods.addAll([
        _copyWithMethod(rowType, _copyWithFields(table, _GeneratedShape.row)),
        _mapMethod(
          name: 'toColumns',
          entries: [
            for (final column in table.columns)
              _MapEntrySpec(
                key: column.name,
                value: _toDatabaseExpression(
                  column,
                  source: refer(_lowerCamel(column.name)),
                ),
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

Class _insertClass(IntrospectedTable table, DartSchemaNaming naming) {
  final insertType = _insertClassName(table, naming);
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
      ..constructors.addAll([
        _decodeFactory(insertType),
        _fromJsonFactory(insertType, table, _GeneratedShape.insert),
      ])
      ..methods.addAll([
        _copyWithMethod(
          insertType,
          _copyWithFields(table, _GeneratedShape.insert),
        ),
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

Class _updateClass(IntrospectedTable table, DartSchemaNaming naming) {
  final updateType = _updateClassName(table, naming);
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
      ..constructors.addAll([
        _decodeFactory(updateType),
        _fromJsonFactory(updateType, table, _GeneratedShape.update),
      ])
      ..methods.addAll([
        _copyWithMethod(
          updateType,
          _copyWithFields(table, _GeneratedShape.update),
        ),
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

Class _tableClass(
  IntrospectedTable table,
  DartSchemaNaming naming, {
  bool encodeMapValues = false,
}) {
  final rowType = _rowClassName(table, naming);
  final insertType = _insertClassName(table, naming);
  final updateType = _updateClassName(table, naming);
  final tableClassName = _tableClassName(table, naming);

  return Class((builder) {
    builder
      ..modifier = ClassModifier.final$
      ..name = tableClassName
      ..extend = _type('SqlTable', [
        refer(rowType),
        refer(insertType),
        refer(updateType),
      ])
      ..constructors.addAll([
        _tableConstConstructor(table),
        Constructor((constructor) {
          constructor
            ..constant = true
            ..name = 'withSchema'
            ..requiredParameters.add(
              Parameter((parameter) {
                parameter
                  ..name = 'schema'
                  ..toThis = true;
              }),
            );
        }),
      ])
      ..fields.addAll([
        Field((field) {
          field
            ..annotations.add(refer('override'))
            ..modifier = FieldModifier.final$
            ..type = refer('String?')
            ..name = 'schema';
        }),
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
              ..assignment = _type('SqlColumn', [_sqlColumnType(column)])
                  .newInstance(const <Expression>[], {
                    'table': refer('table'),
                    'name': literalString(column.name),
                    'nullable': literalBool(column.nullable),
                    'databaseType': literalString(_columnDatabaseType(column)),
                  })
                  .code;
          }),
      ])
      ..methods.addAll([
        _getter('name', refer('String'), literalString(table.name)),
        _getter(
          'columns',
          _listOf(_type('SqlColumn', [refer('Object?')])),
          literalList([
            for (final column in table.columns)
              _instanceColumnExpression(column).property('asObjectColumn'),
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
        if (encodeMapValues)
          _encodeMapMethod('encodeInsert')
        else
          _encodeMethod('encodeInsert', insertType),
        if (encodeMapValues)
          _encodeMapMethod('encodeUpdate')
        else
          _encodeMethod('encodeUpdate', updateType),
      ]);
  });
}

Constructor _tableConstConstructor(IntrospectedTable table) {
  return Constructor((constructor) {
    constructor
      ..constant = true
      ..name = '_'
      ..initializers.add(
        refer('schema').assign(switch (table.schema) {
          final schema? => literalString(schema),
          null => literalNull,
        }).code,
      );
  });
}

Extension _tableColumnsExtension(
  IntrospectedTable table,
  DartSchemaNaming naming,
) {
  final tableClassName = _tableClassName(table, naming);
  return Extension((builder) {
    builder
      ..name = '${tableClassName}Columns'
      ..on = refer(tableClassName)
      ..methods.addAll([
        for (final column in table.columns)
          Method((method) {
            method
              ..type = MethodType.getter
              ..returns = _type('SqlColumn', [_sqlColumnType(column)])
              ..name = _columnFieldName(column.name)
              ..lambda = true
              ..body = _instanceColumnExpression(column).code;
          }),
      ]);
  });
}

Expression _instanceColumnExpression(IntrospectedColumn column) {
  return refer('column').call(
    [literalString(column.name)],
    {
      'nullable': literalBool(column.nullable),
      'databaseType': literalString(_columnDatabaseType(column)),
    },
    [_sqlColumnType(column)],
  );
}

List<_TableImportSpec> _tablePrimaryKeyTypeImports(
  IntrospectedTable table,
  _SchemaGroup group,
  List<_SchemaGroup> schemaGroups,
) {
  final imports = <_TableImportSpec>[];
  final seenPaths = <String>{};
  for (final constraint in table.constraints) {
    if (constraint.kind != IntrospectedTableConstraintKind.foreignKey ||
        constraint.columns.length != 1 ||
        constraint.referencedTable == null ||
        constraint.referencedColumns.length != 1) {
      continue;
    }
    final localColumn = _firstWhereOrNull(
      table.columns,
      (column) => column.name == constraint.columns.single,
    );
    if (localColumn == null || !_hasExtensionBackedValueType(localColumn)) {
      continue;
    }
    final referencedSchema = _schemaName(
      constraint.referencedSchema ?? table.schema,
    );
    final referencedTableName = constraint.referencedTable!;
    if (referencedSchema == group.schemaName &&
        referencedTableName == table.name) {
      continue;
    }
    final referencedGroup = _firstWhereOrNull(
      schemaGroups,
      (candidate) => candidate.schemaName == referencedSchema,
    );
    if (referencedGroup == null) {
      continue;
    }
    final referencedTable = _firstWhereOrNull(
      referencedGroup.tables,
      (candidate) => candidate.name == referencedTableName,
    );
    if (referencedTable == null) {
      continue;
    }
    final path = referencedGroup.schemaName == group.schemaName
        ? _tableFileName(referencedTable)
        : '../../${referencedGroup.folderName}/tables/${_tableFileName(referencedTable)}';
    if (seenPaths.add(path)) {
      imports.add(_TableImportSpec(path: path));
    }
  }
  return imports;
}

final class _TableImportSpec {
  const _TableImportSpec({required this.path});

  final String path;
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}
