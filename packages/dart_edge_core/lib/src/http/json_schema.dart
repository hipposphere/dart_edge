enum JsonSchemaType {
  object('object'),
  array('array'),
  string('string'),
  integer('integer'),
  number('number'),
  boolean('boolean');

  const JsonSchemaType(this.wireValue);

  final String wireValue;
}

/// Dart-only type metadata used by generators when mapping JSON Schema values.
sealed class DartSchemaType {
  const DartSchemaType();

  const factory DartSchemaType.type(Type type) = DartConcreteSchemaType;

  const factory DartSchemaType.named(String name) = DartNamedSchemaType;

  const factory DartSchemaType.parameter(String name) = DartGenericSchemaType;
}

/// Binds a JSON Schema value to a concrete Dart type.
final class DartConcreteSchemaType extends DartSchemaType {
  const DartConcreteSchemaType(this.type) : name = null;

  const DartConcreteSchemaType.named(this.name) : type = null;

  final Type? type;
  final String? name;
}

/// Binds a JSON Schema value to a concrete Dart type by source name.
final class DartNamedSchemaType extends DartSchemaType {
  const DartNamedSchemaType(this.name);

  final String name;
}

/// Binds a JSON Schema value to a generated model type parameter.
final class DartGenericSchemaType extends DartSchemaType {
  const DartGenericSchemaType(this.name);

  final String name;
}

/// Typed JSON Schema model used by route metadata and installed registries.
sealed class JsonSchema {
  const JsonSchema._({
    this.id,
    this.title,
    this.description,
    this.enumValues = const <Object?>[],
    this.nullable = false,
  });

  const factory JsonSchema.any({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
  }) = JsonAnySchema;

  const factory JsonSchema.object({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    Map<String, JsonSchema> properties,
    List<String> required,
    bool? additionalProperties,
  }) = JsonObjectSchema;

  const factory JsonSchema.array({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    JsonSchema? items,
  }) = JsonArraySchema;

  const factory JsonSchema.anyOf(
    List<JsonSchema> schemas, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    DartSchemaType? dartType,
  }) = JsonAnyOfSchema;

  const factory JsonSchema.oneOf(
    List<JsonSchema> schemas, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    DartSchemaType? dartType,
  }) = JsonOneOfSchema;

  const factory JsonSchema.allOf(
    List<JsonSchema> schemas, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    DartSchemaType? dartType,
  }) = JsonAllOfSchema;

  const factory JsonSchema.string({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
    DartSchemaType? dartType,
  }) = JsonStringSchema;

  const factory JsonSchema.integer({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
  }) = JsonIntegerSchema;

  const factory JsonSchema.number({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
  }) = JsonNumberSchema;

  const factory JsonSchema.boolean({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
  }) = JsonBooleanSchema;

  const factory JsonSchema.ref(
    String ref, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
  }) = JsonReferenceSchema;

  const factory JsonSchema.componentRef(
    String schemaId, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
  }) = JsonReferenceSchema.component;

  const factory JsonSchema.raw(Map<String, Object?> schema, {String? id}) =
      JsonRawSchema;

  /// Optional JSON Schema `$id`.
  final String? id;

  /// Optional human-readable schema title.
  final String? title;

  /// Optional human-readable schema description.
  final String? description;

  /// Optional set of exact JSON values accepted by this schema.
  final List<Object?> enumValues;

  /// Whether this schema also allows JSON `null`.
  final bool nullable;

  /// Serializes this schema into a JSON-compatible map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      r'$id': ?id,
      'title': ?title,
      'description': ?description,
      if (enumValues.isNotEmpty) 'enum': enumValues.toList(growable: false),
      ...toJsonKeywords(),
    };
  }

  Map<String, Object?> toJsonKeywords();
}

abstract base class _JsonTypedSchema extends JsonSchema {
  const _JsonTypedSchema({
    required this.type,
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable,
  }) : super._();

  final JsonSchemaType type;

  @override
  Map<String, Object?> toJsonKeywords() {
    return <String, Object?>{
      'type': nullable ? <String>[type.wireValue, 'null'] : type.wireValue,
      ...additionalKeywords(),
    };
  }

  Map<String, Object?> additionalKeywords();
}

final class JsonAnySchema extends JsonSchema {
  const JsonAnySchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
  }) : super._();

  @override
  Map<String, Object?> toJsonKeywords() => const <String, Object?>{};
}

final class JsonObjectSchema extends _JsonTypedSchema {
  const JsonObjectSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.properties = const <String, JsonSchema>{},
    this.required = const <String>[],
    this.additionalProperties,
  }) : super(type: JsonSchemaType.object);

  final Map<String, JsonSchema> properties;
  final List<String> required;
  final bool? additionalProperties;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{
      if (properties.isNotEmpty)
        'properties': <String, Object?>{
          for (final entry in properties.entries)
            entry.key: entry.value.toJson(),
        },
      if (required.isNotEmpty) 'required': required.toList(growable: false),
      'additionalProperties': ?additionalProperties,
    };
  }
}

final class JsonArraySchema extends _JsonTypedSchema {
  const JsonArraySchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.items,
  }) : super(type: JsonSchemaType.array);

  final JsonSchema? items;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{
      if (items case final items?) 'items': items.toJson(),
    };
  }
}

sealed class JsonCompositeSchema extends JsonSchema {
  const JsonCompositeSchema(
    this.schemas, {
    required this.keyword,
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.dartType,
  }) : super._();

  final List<JsonSchema> schemas;
  final String keyword;
  final DartSchemaType? dartType;

  @override
  Map<String, Object?> toJsonKeywords() {
    return <String, Object?>{
      keyword: schemas.map((schema) => schema.toJson()).toList(),
      if (nullable) 'nullable': true,
    };
  }
}

final class JsonAnyOfSchema extends JsonCompositeSchema {
  const JsonAnyOfSchema(
    super.schemas, {
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable,
    super.dartType,
  }) : super(keyword: 'anyOf');
}

final class JsonOneOfSchema extends JsonCompositeSchema {
  const JsonOneOfSchema(
    super.schemas, {
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable,
    super.dartType,
  }) : super(keyword: 'oneOf');
}

final class JsonAllOfSchema extends JsonCompositeSchema {
  const JsonAllOfSchema(
    super.schemas, {
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable,
    super.dartType,
  }) : super(keyword: 'allOf');
}

final class JsonStringSchema extends _JsonTypedSchema {
  const JsonStringSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.format,
    this.dartType,
  }) : super(type: JsonSchemaType.string);

  final String? format;
  final DartSchemaType? dartType;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{'format': ?format};
  }
}

final class JsonIntegerSchema extends _JsonTypedSchema {
  const JsonIntegerSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.format,
  }) : super(type: JsonSchemaType.integer);

  final String? format;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{'format': ?format};
  }
}

final class JsonNumberSchema extends _JsonTypedSchema {
  const JsonNumberSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.format,
  }) : super(type: JsonSchemaType.number);

  final String? format;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{'format': ?format};
  }
}

final class JsonBooleanSchema extends _JsonTypedSchema {
  const JsonBooleanSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
  }) : super(type: JsonSchemaType.boolean);

  @override
  Map<String, Object?> additionalKeywords() => const <String, Object?>{};
}

final class JsonReferenceSchema extends JsonSchema {
  const JsonReferenceSchema(
    this.ref, {
    super.id,
    super.title,
    super.description,
    super.enumValues,
  }) : super._();

  const JsonReferenceSchema.component(
    String schemaId, {
    super.id,
    super.title,
    super.description,
    super.enumValues,
  }) : ref = '#/components/schemas/$schemaId',
       super._();

  final String ref;

  @override
  Map<String, Object?> toJsonKeywords() => <String, Object?>{r'$ref': ref};
}

final class JsonRawSchema extends JsonSchema {
  const JsonRawSchema(this.schema, {super.id}) : super._();

  final Map<String, Object?> schema;

  @override
  String? get id => super.id ?? _stringValue(r'$id');

  @override
  String? get title => _stringValue('title');

  @override
  String? get description => _stringValue('description');

  @override
  List<Object?> get enumValues {
    final values = schema['enum'];
    if (values is List<Object?>) {
      return values;
    }
    if (values is List) {
      return List<Object?>.unmodifiable(values);
    }
    return const <Object?>[];
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{...schema, r'$id': ?id};
  }

  @override
  Map<String, Object?> toJsonKeywords() => schema;

  String? _stringValue(String key) {
    final value = schema[key];
    return value is String ? value : null;
  }
}
