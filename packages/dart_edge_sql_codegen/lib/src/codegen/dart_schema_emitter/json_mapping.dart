part of '../dart_schema_emitter.dart';

Method _copyWithMethod(String className, Iterable<_CopyWithFieldSpec> fields) {
  return Method((method) {
    method
      ..returns = refer(className)
      ..name = 'copyWith'
      ..optionalParameters.addAll([
        for (final field in fields)
          _namedParameter(field.name, type: field.parameterType),
      ])
      ..body = refer(className)
          .newInstance(const <Expression>[], {
            for (final field in fields) field.name: field.value,
          })
          .returned
          .statement;
  });
}

List<_CopyWithFieldSpec> _copyWithFields(
  IntrospectedTable table,
  _GeneratedShape shape,
) {
  return <_CopyWithFieldSpec>[
    for (final column in table.columns) _copyWithField(column, shape),
  ];
}

_CopyWithFieldSpec _copyWithField(
  IntrospectedColumn column,
  _GeneratedShape shape,
) {
  final name = _lowerCamel(column.name);
  final isSqlValueField =
      shape == _GeneratedShape.update ||
      (shape == _GeneratedShape.insert && _isOptionalInsertColumn(column));

  if (isSqlValueField) {
    final fieldType = switch (shape) {
      _GeneratedShape.update => _updateFieldType(column),
      _GeneratedShape.insert => _insertFieldType(column),
      _GeneratedShape.row => throw StateError('Rows do not use SqlValue.'),
    };
    return _CopyWithFieldSpec(
      name: name,
      parameterType: refer('${_typeCode(fieldType)}?'),
      value: CodeExpression(Code('$name ?? this.$name')),
    );
  }

  final normalizedType = _valueType(column);
  final isNullable = column.nullable || normalizedType == 'Object?';
  if (isNullable) {
    return _CopyWithFieldSpec(
      name: name,
      parameterType: refer(
        '${_typeCode(_type('SqlValue', [refer(_nullableType(normalizedType, true))]))}?',
      ),
      value: CodeExpression(
        Code('$name == null || !$name.isPresent ? this.$name : $name.value'),
      ),
    );
  }

  return _CopyWithFieldSpec(
    name: name,
    parameterType: refer('$normalizedType?'),
    value: CodeExpression(Code('$name ?? this.$name')),
  );
}

List<Field> _schemaFields({
  required String className,
  required IntrospectedTable table,
  required _GeneratedShape shape,
  required SqlInt8JsonEncoding int8JsonEncoding,
}) {
  return <Field>[
    _staticConstField(name: 'schemaId', assignment: literalString(className)),
    _staticConstField(
      name: 'schemaRef',
      assignment: refer(
        'JsonSchema',
      ).constInstanceNamed('componentRef', [refer('schemaId')]),
    ),
    _staticConstField(
      name: 'jsonSchema',
      assignment: _jsonSchemaForTable(
        table,
        shape,
        int8JsonEncoding: int8JsonEncoding,
      ),
    ),
  ];
}

Expression _jsonSchemaForTable(
  IntrospectedTable table,
  _GeneratedShape shape, {
  required SqlInt8JsonEncoding int8JsonEncoding,
}) {
  return refer(
    'JsonSchema',
  ).constInstanceNamed('object', const <Expression>[], {
    'id': refer('schemaId'),
    'properties': literalConstMap(
      {
        for (final column in table.columns)
          literalString(column.name): _jsonSchemaForColumn(
            column,
            int8JsonEncoding: int8JsonEncoding,
          ),
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
  _GeneratedShape shape, {
  required SqlInt8JsonEncoding int8JsonEncoding,
}) {
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
              int8JsonEncoding: int8JsonEncoding,
            ),
            _GeneratedShape.insert => _sqlValueFromJsonExpression(
              column,
              optional: _isOptionalInsertColumn(column),
              int8JsonEncoding: int8JsonEncoding,
            ),
            _GeneratedShape.update => _sqlValueFromJsonExpression(
              column,
              optional: true,
              int8JsonEncoding: int8JsonEncoding,
            ),
          },
      }).code;
  });
}

Constructor _decodeFactory(String typeName) {
  return Constructor((constructor) {
    constructor
      ..factory = true
      ..name = 'decode'
      ..requiredParameters.add(_typedParameter('value', refer('Object?')))
      ..lambda = true
      ..body = refer(typeName).newInstanceNamed('fromJson', [
        refer('readJsonObject').call([refer('value')]),
      ]).code;
  });
}

Expression _rowReadExpression(IntrospectedColumn column) {
  final fieldKey = '\${prefix}${column.name}';
  final type = _valueType(column);
  final databaseType = _databaseValueType(column);
  if (_hasStringBackedValueType(column)) {
    final source = column.nullable
        ? refer('row')
              .property('readNullable')
              .call([literalString(fieldKey)], const {}, [refer('String')])
        : refer('row')
              .property('read')
              .call([literalString(fieldKey)], const {}, [refer('String')]);
    final parsed = refer(type).property('fromDatabase').call([source]);
    if (!column.nullable) {
      return parsed;
    }
    return CodeExpression(
      Code('${_code(source)} == null ? null : ${_code(parsed)}'),
    );
  }
  if (_hasExtensionBackedValueType(column)) {
    final source = column.nullable
        ? refer('row')
              .property('readNullable')
              .call([literalString(fieldKey)], const {}, [refer(databaseType)])
        : refer('row')
              .property('read')
              .call([literalString(fieldKey)], const {}, [refer(databaseType)]);
    final parsed = refer(type).call([source]);
    if (!column.nullable) {
      return parsed;
    }
    final nullableParsed = refer(
      type,
    ).call([CodeExpression(Code('${_code(source)}!'))]);
    return CodeExpression(
      Code('${_code(source)} == null ? null : ${_code(nullableParsed)}'),
    );
  }
  if (type == 'Object?') {
    return refer('row')
        .property('read')
        .call(
          [literalString(fieldKey)],
          const <String, Expression>{},
          [refer('Object?')],
        );
  }
  if (type == 'DateTime') {
    final source = column.nullable
        ? refer('row')
              .property('readNullable')
              .call([literalString(fieldKey)], const {}, [refer('Object?')])
        : refer('row')
              .property('read')
              .call([literalString(fieldKey)], const {}, [refer('Object?')]);
    final expression = switch (column.nullable) {
      true =>
        'switch (${_code(source)}) { '
            'null => null, '
            'final DateTime value => value, '
            'final String value => DateTime.parse(value), '
            'final value => value as DateTime '
            '}',
      false =>
        'switch (${_code(source)}) { '
            'final DateTime value => value, '
            'final String value => DateTime.parse(value), '
            'final value => value as DateTime '
            '}',
    };
    return CodeExpression(Code(expression));
  }
  if (type == 'SqlDecimal' || type == 'SqlVector') {
    final source = column.nullable
        ? refer('row')
              .property('readNullable')
              .call([literalString(fieldKey)], const {}, [refer('Object?')])
        : refer('row')
              .property('read')
              .call([literalString(fieldKey)], const {}, [refer('Object?')]);
    final parsed = refer(type).property('fromJson').call([source]);
    if (!column.nullable) {
      return parsed;
    }
    return CodeExpression(
      Code('${_code(source)} == null ? null : ${_code(parsed)}'),
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
  required SqlInt8JsonEncoding int8JsonEncoding,
}) {
  final key = column.name;
  final valueType = _nullableType(_valueType(column), column.nullable);
  final parsed = _fromJsonExpression(
    column,
    source: _jsonLookup(key),
    nullable: column.nullable,
    int8JsonEncoding: int8JsonEncoding,
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
  required SqlInt8JsonEncoding int8JsonEncoding,
}) {
  final type = _valueType(column);
  final databaseType = _databaseValueType(column);

  Expression wrapNullable(Expression expression) {
    if (!nullable) {
      return expression;
    }
    return CodeExpression(
      Code('${_code(source)} == null ? null : ${_code(expression)}'),
    );
  }

  if (_hasStringBackedValueType(column)) {
    final parsed = refer(
      type,
    ).property('fromDatabase').call([source.asA(refer('String'))]);
    return wrapNullable(parsed);
  }

  if (_usesStringInt8JsonEncoding(column, int8JsonEncoding)) {
    final parsed = _parseInt8JsonExpression(column, source);
    if (_hasExtensionBackedValueType(column)) {
      return wrapNullable(refer(type).call([parsed]));
    }
    return wrapNullable(parsed);
  }

  if (_hasExtensionBackedValueType(column)) {
    final parsed = switch (databaseType) {
      'int' => source.asA(refer('num')).property('toInt').call(const []),
      'double' => source.asA(refer('num')).property('toDouble').call(const []),
      'num' => source.asA(refer('num')),
      'bool' => source.asA(refer('bool')),
      'String' => source.asA(refer('String')),
      'DateTime' => refer(
        'DateTime',
      ).property('parse').call([source.asA(refer('String'))]),
      'List<int>' => _type('List', [
        refer('int'),
      ]).newInstanceNamed('from', [source.asA(refer('List'))]),
      'List<Object?>' => _type('List', [
        refer('Object?'),
      ]).newInstanceNamed('from', [source.asA(refer('List'))]),
      'Object?' => source,
      _ => source.asA(refer(databaseType)),
    };
    return wrapNullable(refer(type).call([parsed]));
  }

  if (type == 'SqlDecimal' || type == 'SqlVector') {
    return wrapNullable(refer(type).property('fromJson').call([source]));
  }

  return switch (databaseType) {
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
    _ => wrapNullable(source.asA(refer(databaseType))),
  };
}

Expression _toJsonExpression(
  IntrospectedColumn column, {
  required Expression source,
  bool sourceNullable = false,
  SqlInt8JsonEncoding int8JsonEncoding = SqlInt8JsonEncoding.number,
}) {
  final databaseType = _databaseValueType(column);
  final valueNullable = column.nullable || sourceNullable;

  Expression wrapNullable(Expression expression) {
    if (!valueNullable) {
      return expression;
    }
    return CodeExpression(
      Code('${_code(source)} == null ? null : ${_code(expression)}'),
    );
  }

  if (_hasStringBackedValueType(column)) {
    return valueNullable
        ? CodeExpression(Code('${_code(source)}?.value'))
        : source.property('value');
  }

  if (_hasExtensionBackedValueType(column)) {
    final value = source.property('value');
    if (_usesStringInt8JsonEncoding(column, int8JsonEncoding)) {
      return wrapNullable(value.property('toString').call(const []));
    }
    return switch (databaseType) {
      'DateTime' =>
        valueNullable
            ? CodeExpression(Code('${_code(source)}?.value.toIso8601String()'))
            : value.property('toIso8601String').call(const []),
      'List<int>' => wrapNullable(
        _type('List', [refer('int')]).newInstanceNamed('from', [value]),
      ),
      'List<Object?>' => wrapNullable(
        _type('List', [refer('Object?')]).newInstanceNamed('from', [value]),
      ),
      _ =>
        valueNullable ? CodeExpression(Code('${_code(source)}?.value')) : value,
    };
  }

  if (_usesStringInt8JsonEncoding(column, int8JsonEncoding)) {
    return wrapNullable(source.property('toString').call(const []));
  }

  if (databaseType == 'SqlDecimal' || databaseType == 'SqlVector') {
    return valueNullable
        ? CodeExpression(Code('${_code(source)}?.toJson()'))
        : source.property('toJson').call(const []);
  }

  return switch (databaseType) {
    'DateTime' =>
      valueNullable
          ? CodeExpression(Code('${_code(source)}?.toIso8601String()'))
          : source.property('toIso8601String').call(const []),
    'List<int>' => wrapNullable(
      _type('List', [refer('int')]).newInstanceNamed('from', [source]),
    ),
    'List<Object?>' => wrapNullable(
      _type('List', [refer('Object?')]).newInstanceNamed('from', [source]),
    ),
    _ => source,
  };
}

Expression _jsonSchemaForColumn(
  IntrospectedColumn column, {
  required SqlInt8JsonEncoding int8JsonEncoding,
}) {
  final type = _databaseValueType(column);

  if (_hasStringBackedValueType(column)) {
    return _jsonSchemaFactory(
      'string',
      nullable: column.nullable,
      enumValues: literalConstList(
        _enumValuesForColumn(column).map(literalString).toList(growable: false),
        refer('String'),
      ),
    );
  }

  if (type == 'Object?') {
    return refer('JsonSchema').constInstanceNamed('any', const []);
  }

  if (_usesStringInt8JsonEncoding(column, int8JsonEncoding)) {
    return _jsonSchemaFactory(
      'string',
      nullable: column.nullable,
      format: 'int64',
    );
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
    'SqlDecimal' => _jsonSchemaFactory(
      'string',
      nullable: column.nullable,
      format: 'decimal',
    ),
    'SqlVector' => _jsonSchemaFactory(
      'array',
      nullable: column.nullable,
      items: refer('JsonSchema').constInstanceNamed('number', const []),
    ),
    _ => _jsonSchemaFactory('string', nullable: column.nullable),
  };
}

Expression _jsonSchemaFactory(
  String kind, {
  required bool nullable,
  String? format,
  Expression? items,
  Expression? enumValues,
}) {
  return refer('JsonSchema').constInstanceNamed(kind, const <Expression>[], {
    if (nullable) 'nullable': literalBool(true),
    if (format case final format?) 'format': literalString(format),
    'items': ?items,
    'enumValues': ?enumValues,
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
  SqlInt8JsonEncoding int8JsonEncoding = SqlInt8JsonEncoding.number,
}) {
  final fieldName = _lowerCamel(column.name);
  final isOptional = _isOptionalInsertColumn(column);
  final source = isOptional
      ? refer(fieldName).property('value')
      : refer(fieldName);
  return _MapEntrySpec(
    key: column.name,
    value: encodeJson
        ? _toJsonExpression(
            column,
            source: source,
            sourceNullable: isOptional,
            int8JsonEncoding: int8JsonEncoding,
          )
        : _toDatabaseExpression(
            column,
            source: source,
            sourceNullable: isOptional,
          ),
    condition: isOptional ? refer(fieldName).property('isPresent') : null,
  );
}

_MapEntrySpec _updateMapEntry(
  IntrospectedColumn column, {
  bool encodeJson = false,
  SqlInt8JsonEncoding int8JsonEncoding = SqlInt8JsonEncoding.number,
}) {
  final fieldName = _lowerCamel(column.name);
  final source = refer(fieldName).property('value');
  return _MapEntrySpec(
    key: column.name,
    value: encodeJson
        ? _toJsonExpression(
            column,
            source: source,
            sourceNullable: true,
            int8JsonEncoding: int8JsonEncoding,
          )
        : _toDatabaseExpression(column, source: source, sourceNullable: true),
    condition: refer(fieldName).property('isPresent'),
  );
}

bool _usesStringInt8JsonEncoding(
  IntrospectedColumn column,
  SqlInt8JsonEncoding int8JsonEncoding,
) {
  return int8JsonEncoding == SqlInt8JsonEncoding.string &&
      _isPostgresInt8Column(column);
}

bool _isPostgresInt8Column(IntrospectedColumn column) {
  return switch (_normalizeDatabaseType(column.databaseType)) {
    'int8' || 'bigint' => true,
    _ => false,
  };
}

Expression _parseInt8JsonExpression(
  IntrospectedColumn column,
  Expression source,
) {
  final columnName = _escapeLiteral(column.name);
  return CodeExpression(
    Code(
      'switch (${_code(source)}) { '
      'final String value => int.parse(value), '
      'final num value => value.toInt(), '
      "final value => throw FormatException('Invalid $columnName: \$value'), "
      '}',
    ),
  );
}

Expression _toDatabaseExpression(
  IntrospectedColumn column, {
  required Expression source,
  bool sourceNullable = false,
}) {
  if (!_hasStringBackedValueType(column)) {
    if (!_hasExtensionBackedValueType(column)) {
      return source;
    }
    return column.nullable || sourceNullable
        ? CodeExpression(Code('${_code(source)}?.value'))
        : source.property('value');
  }
  return column.nullable || sourceNullable
      ? CodeExpression(Code('${_code(source)}?.value'))
      : source.property('value');
}

List<String> _enumValuesForColumn(IntrospectedColumn column) {
  if (_isConstrainedTextColumn(column)) {
    return column.constrainedValues;
  }
  return column.enumValues;
}
