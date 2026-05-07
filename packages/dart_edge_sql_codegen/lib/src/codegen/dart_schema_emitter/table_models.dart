part of '../dart_schema_emitter.dart';

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
