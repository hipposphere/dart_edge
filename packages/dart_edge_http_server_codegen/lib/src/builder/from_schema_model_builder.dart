import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:source_gen/source_gen.dart';

/// Build-time description of a model generated from a JSON Schema.
final class FromSchemaModelSpec {
  const FromSchemaModelSpec({
    required this.publicName,
    required this.backingClassName,
    required this.schema,
    required this.schemaId,
    required this.refModels,
    required this.responseStatus,
  });

  final String publicName;
  final String backingClassName;
  final JsonSchema schema;
  final String schemaId;
  final Map<String, SchemaRefModelSpec> refModels;
  final int responseStatus;
}

FromSchemaModelSpec buildFromSchemaModel(
  Element element,
  ConstantReader reader,
) {
  if (element is! TypeAliasElement) {
    throw InvalidGenerationSourceError(
      '@FromSchema can only be used on type aliases.',
      element: element,
    );
  }

  if (element.typeParameters.isNotEmpty) {
    throw InvalidGenerationSourceError(
      '@FromSchema does not support generic type aliases yet.',
      element: element,
    );
  }

  final sourceSchema = jsonSchemaFromDartObject(
    reader.read('schema').objectValue,
    element: element,
  );

  final registryReader = reader.read('registry');
  JsonSchemaRegistry? registry;
  if (!registryReader.isNull) {
    registry = _jsonSchemaRegistryFromDartObject(
      registryReader.objectValue,
      element: element,
    );
  }

  final schema = _resolveRootSchema(
    sourceSchema,
    registry: registry,
    element: element,
  );

  if (registry != null) {
    _validateSchemaReferences(schema, registry, element);
  }

  final refModels = _schemaRefModelsFromDartObject(
    reader.read('refs').objectValue,
    registry: registry,
    element: element,
  );

  final publicName = element.displayName;
  return FromSchemaModelSpec(
    publicName: publicName,
    backingClassName: '_\$$publicName',
    schema: schema,
    schemaId: _schemaIdForModel(sourceSchema, schema, publicName),
    refModels: refModels,
    responseStatus: reader.peek('responseStatus')?.intValue ?? 200,
  );
}

JsonSchema jsonSchemaFromDartObject(
  DartObject object, {
  required Element element,
}) {
  final typeName = object.type?.element?.name;

  return switch (typeName) {
    'JsonAnySchema' => JsonSchema.any(
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
    ),
    'JsonObjectSchema' => JsonSchema.object(
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
      nullable: _boolField(object, 'nullable') ?? false,
      properties: _schemaMapField(object, 'properties', element: element),
      required: _stringListField(object, 'required'),
      additionalProperties: _boolField(object, 'additionalProperties'),
    ),
    'JsonArraySchema' => JsonSchema.array(
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
      nullable: _boolField(object, 'nullable') ?? false,
      items: switch (_field(object, 'items')) {
        final items? when !items.isNull => jsonSchemaFromDartObject(
          items,
          element: element,
        ),
        _ => null,
      },
    ),
    'JsonStringSchema' => JsonSchema.string(
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
      nullable: _boolField(object, 'nullable') ?? false,
      format: _stringField(object, 'format'),
    ),
    'JsonIntegerSchema' => JsonSchema.integer(
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
      nullable: _boolField(object, 'nullable') ?? false,
      format: _stringField(object, 'format'),
    ),
    'JsonNumberSchema' => JsonSchema.number(
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
      nullable: _boolField(object, 'nullable') ?? false,
      format: _stringField(object, 'format'),
    ),
    'JsonBooleanSchema' => JsonSchema.boolean(
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
      nullable: _boolField(object, 'nullable') ?? false,
    ),
    'JsonReferenceSchema' => JsonSchema.ref(
      _stringField(object, 'ref') ?? '',
      id: _stringField(object, 'id'),
      title: _stringField(object, 'title'),
      description: _stringField(object, 'description'),
      enumValues: _objectListField(object, 'enumValues', element: element),
    ),
    'JsonRawSchema' => JsonSchema.raw(
      _objectMapField(object, 'schema', element: element),
      id: _stringField(object, 'id'),
    ),
    _ => throw InvalidGenerationSourceError(
      '@FromSchema expected a const JsonSchema value, got $typeName.',
      element: element,
    ),
  };
}

String generateFromSchemaModels(List<FromSchemaModelSpec> models) {
  const ignoreForFile = '// ignore_for_file: unused_element, unused_field\n\n';
  final buffer = StringBuffer(ignoreForFile);
  for (final model in models) {
    if (buffer.length > ignoreForFile.length) {
      buffer.writeln();
    }
    _writeModel(buffer, model);
  }
  return buffer.toString();
}

void _writeModel(StringBuffer buffer, FromSchemaModelSpec model) {
  switch (model.schema) {
    case JsonObjectSchema():
      _writeObjectModel(buffer, model);
    case JsonStringSchema(:final enumValues) when enumValues.isNotEmpty:
      _writeStringEnumModel(buffer, model);
    case _:
      throw StateError('Unsupported FromSchema model schema ${model.schema}.');
  }
}

void _writeObjectModel(StringBuffer buffer, FromSchemaModelSpec model) {
  final fields = _modelFields(model);

  buffer
    ..writeln(
      'final class ${model.backingClassName} implements JsonEncodable {',
    )
    ..writeln('  const ${model.backingClassName}({');

  for (final field in fields) {
    final required = field.requiredParameter ? 'required ' : '';
    buffer.writeln('    ${required}this.${field.name},');
  }

  buffer
    ..writeln('  });')
    ..writeln()
    ..writeln('  static const schemaId = ${_dartString(model.schemaId)};')
    ..writeln()
    ..writeln('  static const schemaRef = JsonSchema.ref(schemaId);')
    ..writeln()
    ..writeln('  static const RequestBody requestBody = RequestBody.json(')
    ..writeln('    schema: schemaRef,')
    ..writeln('    decoder: fromJson,')
    ..writeln('  );')
    ..writeln()
    ..writeln('  static const ResponseSpec response = ResponseSpec.json(')
    ..writeln('    status: ${model.responseStatus},')
    ..writeln('    schema: schemaRef,')
    ..writeln('  );');

  for (final field in fields) {
    buffer
      ..writeln()
      ..writeln('  final ${field.dartType} ${field.name};');
  }

  buffer
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Map<String, Object?> toJson() => <String, Object?>{');

  for (final field in fields) {
    buffer.writeln(
      '    ${_dartString(field.wireName)}: '
      '${_encodeValue(field.schema, field.name, nullable: field.nullable, refModels: model.refModels)},',
    );
  }

  buffer
    ..writeln('  };')
    ..writeln()
    ..writeln('  static ${model.publicName} fromJson(Object? value) {')
    ..writeln('    final json = value! as Map<String, Object?>;')
    ..writeln('    return ${model.publicName}(');

  for (final field in fields) {
    buffer.writeln(
      '      ${field.name}: '
      '${_decodeValue(field.schema, "json[${_dartString(field.wireName)}]", nullable: field.nullable, refModels: model.refModels)},',
    );
  }

  buffer
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}');
}

void _writeStringEnumModel(StringBuffer buffer, FromSchemaModelSpec model) {
  final schema = model.schema;
  if (schema is! JsonStringSchema) {
    throw StateError('Expected JsonStringSchema, got $schema.');
  }
  final values = _stringEnumValues(schema, model.publicName);

  buffer.writeln('enum ${model.backingClassName} implements JsonEncodable {');

  for (var i = 0; i < values.length; i += 1) {
    final separator = i == values.length - 1 ? ';' : ',';
    buffer.writeln(
      '  ${values[i].name}(${_dartString(values[i].wireValue)})$separator',
    );
  }

  buffer
    ..writeln()
    ..writeln('  const ${model.backingClassName}(this.value);')
    ..writeln()
    ..writeln('  final String value;')
    ..writeln()
    ..writeln('  static const schemaId = ${_dartString(model.schemaId)};')
    ..writeln()
    ..writeln('  static const schemaRef = JsonSchema.ref(schemaId);')
    ..writeln()
    ..writeln('  static const RequestBody requestBody = RequestBody.json(')
    ..writeln('    schema: schemaRef,')
    ..writeln('    decoder: fromJson,')
    ..writeln('  );')
    ..writeln()
    ..writeln('  static const ResponseSpec response = ResponseSpec.json(')
    ..writeln('    status: ${model.responseStatus},')
    ..writeln('    schema: schemaRef,')
    ..writeln('  );')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  String toJson() => value;')
    ..writeln()
    ..writeln('  static ${model.publicName} fromJson(Object? value) {')
    ..writeln('    return switch (value) {');

  for (final value in values) {
    buffer.writeln(
      '      ${_dartString(value.wireValue)} => '
      '${model.publicName}.${value.name},',
    );
  }

  buffer
    ..writeln(
      '      _ => throw ArgumentError.value('
      'value, \'value\', \'Expected ${model.publicName} JSON enum value.\'),',
    )
    ..writeln('    };')
    ..writeln('  }')
    ..writeln('}');
}

List<_SchemaFieldSpec> _modelFields(FromSchemaModelSpec model) {
  final schema = model.schema;
  if (schema is! JsonObjectSchema) {
    throw StateError('Expected JsonObjectSchema, got $schema.');
  }

  final fields = <_SchemaFieldSpec>[];
  final fieldNames = <String>{};
  final required = schema.required.toSet();

  for (final entry in schema.properties.entries) {
    final fieldName = _fieldName(entry.key);
    if (!fieldNames.add(fieldName)) {
      throw InvalidGenerationSourceError(
        'Schema ${model.schemaId} contains duplicate Dart field name '
        '$fieldName.',
      );
    }

    final requiredParameter = required.contains(entry.key);
    final nullable = !requiredParameter || entry.value.nullable;
    fields.add(
      _SchemaFieldSpec(
        wireName: entry.key,
        name: fieldName,
        dartType: _schemaDartType(
          entry.value,
          nullable: nullable,
          refModels: model.refModels,
        ),
        schema: entry.value,
        requiredParameter: requiredParameter,
        nullable: nullable,
      ),
    );
  }

  return fields;
}

String _schemaDartType(
  JsonSchema schema, {
  required bool nullable,
  required Map<String, SchemaRefModelSpec> refModels,
}) {
  final type = switch (schema) {
    JsonStringSchema() => 'String',
    JsonIntegerSchema() => 'int',
    JsonNumberSchema() => 'num',
    JsonBooleanSchema() => 'bool',
    JsonArraySchema(:final items) =>
      'List<${items == null ? 'Object?' : _schemaDartType(items, nullable: items.nullable, refModels: refModels)}>',
    JsonReferenceSchema(:final ref) =>
      _refModelForReference(ref, refModels)?.typeName ??
          _typeNameForSchemaRef(ref) ??
          'Object?',
    JsonObjectSchema() || JsonRawSchema() => 'Map<String, Object?>',
    JsonAnySchema() => 'Object?',
    _ => 'Object?',
  };

  if (!nullable || type.endsWith('?')) {
    return type;
  }
  return '$type?';
}

String _decodeValue(
  JsonSchema schema,
  String source, {
  required bool nullable,
  required Map<String, SchemaRefModelSpec> refModels,
}) {
  return switch (schema) {
    JsonStringSchema() =>
      nullable ? '$source as String?' : '$source! as String',
    JsonIntegerSchema() => nullable ? '$source as int?' : '$source! as int',
    JsonNumberSchema() => nullable ? '$source as num?' : '$source! as num',
    JsonBooleanSchema() => nullable ? '$source as bool?' : '$source! as bool',
    JsonArraySchema(:final items) => _decodeArrayValue(
      items,
      source,
      nullable: nullable,
      refModels: refModels,
    ),
    JsonReferenceSchema(:final ref) => _decodeReferenceValue(
      ref,
      source,
      nullable: nullable,
      refModels: refModels,
    ),
    JsonObjectSchema() || JsonRawSchema() =>
      nullable
          ? '$source == null ? null : Map<String, Object?>.from($source as Map)'
          : 'Map<String, Object?>.from($source! as Map)',
    JsonAnySchema() => source,
    _ => source,
  };
}

String _decodeArrayValue(
  JsonSchema? items,
  String source, {
  required bool nullable,
  required Map<String, SchemaRefModelSpec> refModels,
}) {
  final itemExpression = items == null
      ? 'item'
      : _decodeValue(
          items,
          'item',
          nullable: items.nullable,
          refModels: refModels,
        );

  if (nullable) {
    return '($source as List<Object?>?)'
        '?.map((item) => $itemExpression)'
        '.toList()';
  }

  return '($source! as List<Object?>)'
      '.map((item) => $itemExpression)'
      '.toList()';
}

String _decodeReferenceValue(
  String ref,
  String source, {
  required bool nullable,
  required Map<String, SchemaRefModelSpec> refModels,
}) {
  final refModel = _refModelForReference(ref, refModels);
  if (refModel != null) {
    final value = 'Map<String, Object?>.from($source! as Map)';
    if (nullable) {
      return '$source == null ? null : ${refModel.typeName}.fromJson($value)';
    }
    return '${refModel.typeName}.fromJson($value)';
  }

  final typeName = _typeNameForSchemaRef(ref);
  if (typeName == null) {
    return source;
  }

  if (nullable) {
    return '$source == null ? null : $typeName.fromJson($source)';
  }
  return '$typeName.fromJson($source)';
}

String _encodeValue(
  JsonSchema schema,
  String source, {
  required bool nullable,
  required Map<String, SchemaRefModelSpec> refModels,
}) {
  return switch (schema) {
    JsonArraySchema(:final items) => _encodeArrayValue(
      items,
      source,
      nullable: nullable,
      refModels: refModels,
    ),
    JsonReferenceSchema(:final ref) => _encodeReferenceValue(
      ref,
      source,
      nullable: nullable,
      refModels: refModels,
    ),
    _ => source,
  };
}

String _encodeArrayValue(
  JsonSchema? items,
  String source, {
  required bool nullable,
  required Map<String, SchemaRefModelSpec> refModels,
}) {
  final itemExpression = items == null
      ? 'item'
      : _encodeValue(
          items,
          'item',
          nullable: items.nullable,
          refModels: refModels,
        );
  final receiver = nullable ? '$source?' : source;
  return '$receiver.map((item) => $itemExpression).toList()';
}

String _encodeReferenceValue(
  String ref,
  String source, {
  required bool nullable,
  required Map<String, SchemaRefModelSpec> refModels,
}) {
  final typeName =
      _refModelForReference(ref, refModels)?.typeName ??
      _typeNameForSchemaRef(ref);
  if (typeName == null) {
    return source;
  }
  return nullable ? '$source?.toJson()' : '$source.toJson()';
}

JsonSchemaRegistry _jsonSchemaRegistryFromDartObject(
  DartObject object, {
  required Element element,
}) {
  final schemas = _field(object, 'schemas')?.toListValue();
  if (schemas == null) {
    throw InvalidGenerationSourceError(
      '@FromSchema expected registry to be a const JsonSchemaRegistry.',
      element: element,
    );
  }

  return JsonSchemaRegistry(
    schemas: [
      for (final schema in schemas)
        jsonSchemaFromDartObject(schema, element: element),
    ],
  );
}

Map<String, SchemaRefModelSpec> _schemaRefModelsFromDartObject(
  DartObject object, {
  required JsonSchemaRegistry? registry,
  required Element element,
}) {
  if (object.isNull) {
    return const <String, SchemaRefModelSpec>{};
  }

  final values = object.toListValue();
  if (values == null) {
    throw InvalidGenerationSourceError(
      '@FromSchema refs must be a const List<SchemaRefModel>.',
      element: element,
    );
  }

  final refModels = <String, SchemaRefModelSpec>{};
  for (final value in values) {
    final refModel = _schemaRefModelFromDartObject(
      value,
      registry: registry,
      element: element,
    );
    if (refModels.containsKey(refModel.schemaId)) {
      throw InvalidGenerationSourceError(
        '@FromSchema refs contains duplicate schema id ${refModel.schemaId}.',
        element: element,
      );
    }
    refModels[refModel.schemaId] = refModel;
  }
  return refModels;
}

SchemaRefModelSpec _schemaRefModelFromDartObject(
  DartObject object, {
  required JsonSchemaRegistry? registry,
  required Element element,
}) {
  final type = _field(object, 'type')?.toTypeValue();
  final typeName = type?.element?.name;
  if (typeName == null || typeName.isEmpty) {
    throw InvalidGenerationSourceError(
      '@FromSchema refs entries must be const SchemaRefModel(Type) values.',
      element: element,
    );
  }

  final schemaId = _stringField(object, 'schemaId') ?? typeName;
  if (schemaId.isEmpty) {
    throw InvalidGenerationSourceError(
      '@FromSchema refs entries must use non-empty schema ids.',
      element: element,
    );
  }

  if (registry != null && registry.schemaFor(schemaId) == null) {
    throw InvalidGenerationSourceError(
      'Schema ref model $typeName points to schema id $schemaId, which is not '
      'present in the supplied registry.',
      element: element,
    );
  }

  return SchemaRefModelSpec(schemaId: schemaId, typeName: typeName);
}

JsonSchema _resolveRootSchema(
  JsonSchema schema, {
  required JsonSchemaRegistry? registry,
  required Element element,
}) {
  if (_supportedRootSchema(schema)) {
    return schema;
  }

  if (schema case JsonReferenceSchema(:final ref)) {
    final id = _schemaIdFromReference(ref);
    if (id == null) {
      throw InvalidGenerationSourceError(
        '@FromSchema cannot resolve external or non-component schema '
        'reference $ref.',
        element: element,
      );
    }
    final resolvedSchema = registry?.schemaFor(id);
    if (resolvedSchema == null) {
      throw InvalidGenerationSourceError(
        'Schema reference $ref is not present in the supplied registry.',
        element: element,
      );
    }
    if (_supportedRootSchema(resolvedSchema)) {
      return resolvedSchema;
    }
    throw InvalidGenerationSourceError(
      '@FromSchema resolved $ref to an unsupported schema.',
      element: element,
    );
  }

  throw InvalidGenerationSourceError(
    '@FromSchema supports object schemas and string schemas with enumValues.',
    element: element,
  );
}

bool _supportedRootSchema(JsonSchema schema) {
  return schema is JsonObjectSchema ||
      (schema is JsonStringSchema && schema.enumValues.isNotEmpty);
}

String _schemaIdForModel(
  JsonSchema sourceSchema,
  JsonSchema resolvedSchema,
  String publicName,
) {
  if (sourceSchema case JsonReferenceSchema(:final ref)) {
    return _schemaIdFromReference(ref) ?? sourceSchema.id ?? publicName;
  }
  return resolvedSchema.id ?? publicName;
}

void _validateSchemaReferences(
  JsonSchema schema,
  JsonSchemaRegistry registry,
  Element element,
) {
  for (final ref in _schemaRefs(schema)) {
    final id = _schemaIdFromReference(ref);
    if (id != null && registry.schemaFor(id) == null) {
      throw InvalidGenerationSourceError(
        'Schema reference $ref is not present in the supplied registry.',
        element: element,
      );
    }
  }
}

Iterable<String> _schemaRefs(JsonSchema schema) sync* {
  switch (schema) {
    case JsonObjectSchema(:final properties):
      for (final property in properties.values) {
        yield* _schemaRefs(property);
      }
    case JsonArraySchema(:final items):
      if (items != null) {
        yield* _schemaRefs(items);
      }
    case JsonReferenceSchema(:final ref):
      yield ref;
    case JsonRawSchema() || JsonAnySchema() || JsonStringSchema():
    case JsonIntegerSchema() || JsonNumberSchema() || JsonBooleanSchema():
    case _:
  }
}

Map<String, JsonSchema> _schemaMapField(
  DartObject object,
  String name, {
  required Element element,
}) {
  final value = _field(object, name);
  final map = value?.toMapValue();
  if (map == null) {
    return const <String, JsonSchema>{};
  }

  return <String, JsonSchema>{
    for (final entry in map.entries)
      _requiredStringObject(entry.key, element: element):
          jsonSchemaFromDartObject(entry.value!, element: element),
  };
}

Map<String, Object?> _objectMapField(
  DartObject object,
  String name, {
  required Element element,
}) {
  final map = _field(object, name)?.toMapValue();
  if (map == null) {
    return const <String, Object?>{};
  }
  return _objectMap(map, element: element);
}

List<Object?> _objectListField(
  DartObject object,
  String name, {
  required Element element,
}) {
  final values = _field(object, name)?.toListValue();
  if (values == null) {
    return const <Object?>[];
  }
  return [for (final value in values) _objectValue(value, element: element)];
}

Map<String, Object?> _objectMap(
  Map<DartObject?, DartObject?> map, {
  required Element element,
}) {
  return <String, Object?>{
    for (final entry in map.entries)
      _requiredStringObject(entry.key, element: element): _objectValue(
        entry.value,
        element: element,
      ),
  };
}

Object? _objectValue(DartObject? object, {required Element element}) {
  if (object == null || object.isNull) {
    return null;
  }
  if (object.toStringValue() case final value?) {
    return value;
  }
  if (object.toBoolValue() case final value?) {
    return value;
  }
  if (object.toIntValue() case final value?) {
    return value;
  }
  if (object.toDoubleValue() case final value?) {
    return value;
  }
  if (object.toListValue() case final values?) {
    return [for (final value in values) _objectValue(value, element: element)];
  }
  if (object.toMapValue() case final map?) {
    return _objectMap(map, element: element);
  }
  throw InvalidGenerationSourceError(
    'Unsupported raw JSON Schema value ${object.type}.',
    element: element,
  );
}

List<String> _stringListField(DartObject object, String name) {
  return [
    for (final value
        in _field(object, name)?.toListValue() ?? const <DartObject>[])
      ?value.toStringValue(),
  ];
}

String? _stringField(DartObject object, String name) {
  final value = _field(object, name);
  if (value == null || value.isNull) {
    return null;
  }
  return value.toStringValue();
}

bool? _boolField(DartObject object, String name) {
  final value = _field(object, name);
  if (value == null || value.isNull) {
    return null;
  }
  return value.toBoolValue();
}

DartObject? _field(DartObject object, String name) {
  final field = object.getField(name);
  if (field != null) {
    return field;
  }

  final invocation = object.constructorInvocation;
  if (invocation == null) {
    return null;
  }

  if (invocation.namedArguments[name] case final value?) {
    return value;
  }

  if ((name == 'ref' || name == 'schema' || name == 'type') &&
      invocation.positionalArguments.isNotEmpty) {
    return invocation.positionalArguments.first;
  }

  return null;
}

String _requiredStringObject(DartObject? object, {required Element element}) {
  final value = object?.toStringValue();
  if (value == null) {
    throw InvalidGenerationSourceError(
      'JSON Schema map keys must be strings.',
      element: element,
    );
  }
  return value;
}

String? _typeNameForSchemaRef(String ref) {
  final id = _schemaIdFromReference(ref);
  if (id == null) {
    return null;
  }
  return _upperCamel(id);
}

SchemaRefModelSpec? _refModelForReference(
  String ref,
  Map<String, SchemaRefModelSpec> refModels,
) {
  final id = _schemaIdFromReference(ref);
  if (id == null) {
    return null;
  }
  return refModels[id];
}

String? _schemaIdFromReference(String ref) {
  const componentPrefix = '#/components/schemas/';
  if (ref.startsWith(componentPrefix)) {
    return ref.substring(componentPrefix.length);
  }
  if (ref.startsWith('#') || (Uri.tryParse(ref)?.hasScheme ?? false)) {
    return null;
  }
  return ref;
}

String _fieldName(String wireName) {
  if (_validIdentifier(wireName) &&
      !_dartKeywords.contains(wireName) &&
      !wireName.startsWith('_')) {
    return wireName;
  }

  final parts = _identifierParts(wireName);
  if (parts.isEmpty) {
    return 'field';
  }

  final first = parts.first.toLowerCase();
  final rest = parts.skip(1).map(_capitalize).join();
  var name = '$first$rest';
  if (name.isEmpty || RegExp(r'^[0-9]').hasMatch(name)) {
    name = 'field${_capitalize(name)}';
  }
  if (_dartKeywords.contains(name) || name.startsWith('_')) {
    return '${name}Value';
  }
  return name;
}

List<_StringEnumValueSpec> _stringEnumValues(
  JsonStringSchema schema,
  String publicName,
) {
  final values = <_StringEnumValueSpec>[];
  final names = <String>{};

  for (final value in schema.enumValues) {
    if (value is! String) {
      throw InvalidGenerationSourceError(
        '@FromSchema can generate $publicName as a Dart enum only when every '
        'JsonSchema.string enumValues entry is a string.',
      );
    }

    final name = _enumValueName(value);
    if (!names.add(name)) {
      throw InvalidGenerationSourceError(
        'Schema ${schema.id ?? publicName} contains duplicate Dart enum value '
        'name $name.',
      );
    }
    values.add(_StringEnumValueSpec(name: name, wireValue: value));
  }

  return values;
}

String _enumValueName(String wireValue) {
  if (_validIdentifier(wireValue) &&
      !_dartKeywords.contains(wireValue) &&
      !wireValue.startsWith('_') &&
      !RegExp(r'^[A-Z]').hasMatch(wireValue)) {
    return wireValue;
  }

  final parts = _identifierParts(wireValue);
  var name = switch (parts) {
    [] => 'value',
    [final first, ...final rest] =>
      '${first.toLowerCase()}${rest.map(_capitalize).join()}',
  };

  if (RegExp(r'^[0-9]').hasMatch(name)) {
    name = 'value${_capitalize(name)}';
  }
  if (_dartKeywords.contains(name) || name.startsWith('_')) {
    return '${name}Value';
  }
  return name;
}

String _upperCamel(String value) {
  if (_validIdentifier(value) &&
      !_dartKeywords.contains(value) &&
      RegExp(r'^[A-Z]').hasMatch(value)) {
    return value;
  }

  final parts = _identifierParts(value);
  if (parts.isEmpty) {
    return 'GeneratedSchema';
  }
  return parts.map(_capitalize).join();
}

List<String> _identifierParts(String value) {
  return value
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

bool _validIdentifier(String value) {
  return RegExp(r'^[A-Za-z$][A-Za-z0-9$]*$').hasMatch(value);
}

String _dartString(String value) => jsonEncode(value);

final class _SchemaFieldSpec {
  const _SchemaFieldSpec({
    required this.wireName,
    required this.name,
    required this.dartType,
    required this.schema,
    required this.requiredParameter,
    required this.nullable,
  });

  final String wireName;
  final String name;
  final String dartType;
  final JsonSchema schema;
  final bool requiredParameter;
  final bool nullable;
}

final class _StringEnumValueSpec {
  const _StringEnumValueSpec({required this.name, required this.wireValue});

  final String name;
  final String wireValue;
}

final class SchemaRefModelSpec {
  const SchemaRefModelSpec({required this.schemaId, required this.typeName});

  final String schemaId;
  final String typeName;
}

const _dartKeywords = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};
