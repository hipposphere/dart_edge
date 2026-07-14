/// JSON Schema primitive type keywords supported by this package.
enum JsonSchemaType {
  /// JSON object values.
  object('object'),

  /// JSON array values.
  array('array'),

  /// JSON string values.
  string('string'),

  /// JSON integer values.
  integer('integer'),

  /// JSON number values.
  number('number'),

  /// JSON boolean values.
  boolean('boolean');

  const JsonSchemaType(this.wireValue);

  /// Keyword value written into serialized JSON Schema documents.
  final String wireValue;
}

/// Dart conversion strategy attached to [DartSchemaType] metadata.
enum DartSchemaConversion {
  /// Let generators choose the historical conversion for the schema shape.
  ///
  /// String schemas use value-wrapper conversion, while object, reference, and
  /// composite schemas use model conversion.
  infer,

  /// Convert with `Type(jsonValue)` when decoding and `value.value` when
  /// encoding.
  ///
  /// This is intended for extension types and small scalar wrappers.
  value,

  /// Convert with `Type.decode(jsonValue)` when decoding and `value.toJson()`
  /// when encoding.
  ///
  /// This is intended for classes and generated JSON models.
  model,
}

/// Dart-only type metadata used by generators when mapping JSON Schema values.
///
/// This metadata never appears in [JsonSchema.toJson]. It lets code generators
/// preserve a richer Dart type than the JSON value can express by itself, such
/// as an extension type backed by a string ID.
sealed class DartSchemaType {
  const DartSchemaType();

  /// Uses a concrete [Type] object as the generated Dart type.
  ///
  /// This is useful when the schema constant lives in the same library as the
  /// Dart type and the generator can resolve the type object.
  const factory DartSchemaType.type(
    Type type, {
    DartSchemaConversion conversion,
  }) = DartConcreteSchemaType;

  /// Uses a source-level Dart type name with inferred conversion.
  ///
  /// Prefer [value] or [model] when the conversion is known. This constructor is
  /// kept for schemas that should use Dart Edge's historical schema-shape
  /// inference.
  const factory DartSchemaType.named(
    String name, {
    DartSchemaConversion conversion,
  }) = DartNamedSchemaType;

  /// Uses a source-level Dart type name as a value wrapper.
  ///
  /// Generators decode with `Type(jsonValue)` and encode with `value.value`.
  const factory DartSchemaType.value(String name) = DartNamedSchemaType.value;

  /// Uses a source-level Dart type name as a JSON model.
  ///
  /// Generators decode with `Type.decode(jsonValue)` and encode with
  /// `value.toJson()`.
  const factory DartSchemaType.model(String name) = DartNamedSchemaType.model;

  /// Uses a generated model type parameter as the Dart type.
  ///
  /// This is intended for schemas shared by generic generated models.
  const factory DartSchemaType.parameter(String name) = DartGenericSchemaType;
}

/// Binds a JSON Schema value to a concrete Dart type.
final class DartConcreteSchemaType extends DartSchemaType {
  /// Creates metadata from a concrete Dart [Type].
  const DartConcreteSchemaType(
    this.type, {
    this.conversion = DartSchemaConversion.infer,
  }) : name = null;

  /// Creates metadata from a concrete Dart type name.
  ///
  /// This constructor is retained for generated code that needs a concrete type
  /// spelling but cannot pass a [Type] object.
  const DartConcreteSchemaType.named(
    this.name, {
    this.conversion = DartSchemaConversion.infer,
  }) : type = null;

  /// Concrete Dart type object, when available.
  final Type? type;

  /// Concrete Dart type name, when the type object is not available.
  final String? name;

  /// Conversion used by generators for this type.
  final DartSchemaConversion conversion;
}

/// Binds a JSON Schema value to a concrete Dart type by source name.
final class DartNamedSchemaType extends DartSchemaType {
  /// Creates metadata for a Dart type named [name].
  const DartNamedSchemaType(
    this.name, {
    this.conversion = DartSchemaConversion.infer,
  });

  /// Creates metadata for a value-wrapper Dart type named [name].
  const DartNamedSchemaType.value(this.name)
    : conversion = DartSchemaConversion.value;

  /// Creates metadata for a JSON model Dart type named [name].
  const DartNamedSchemaType.model(this.name)
    : conversion = DartSchemaConversion.model;

  /// Source-level Dart type name.
  final String name;

  /// Conversion used by generators for this type.
  final DartSchemaConversion conversion;
}

/// Binds a JSON Schema value to a generated model type parameter.
final class DartGenericSchemaType extends DartSchemaType {
  /// Creates metadata for a generated type parameter named [name].
  const DartGenericSchemaType(this.name);

  /// Generated type parameter name.
  final String name;
}

/// Typed JSON Schema model used by route metadata and installed registries.
///
/// The model covers a practical, typed subset of JSON Schema suitable for
/// generated Dart contracts and schema registries.
/// Use [toJson] when a JSON-compatible schema map is needed for publication.
sealed class JsonSchema {
  const JsonSchema._({
    this.id,
    this.title,
    this.description,
    this.enumValues = const <Object?>[],
    this.nullable = false,
  });

  /// Describes a value with no additional constraints.
  ///
  /// Serialization omits a `type` keyword, which means any JSON value is
  /// accepted by consumers that follow JSON Schema semantics.
  const factory JsonSchema.any({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
  }) = JsonAnySchema;

  /// Describes a JSON object.
  ///
  /// [properties] maps JSON field names to their schemas. [required] contains
  /// the JSON field names that must be present. [additionalProperties] controls
  /// whether fields outside [properties] are accepted when serialized.
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

  /// Describes a JSON array.
  ///
  /// When [items] is provided it describes every element in the array.
  const factory JsonSchema.array({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    JsonSchema? items,
  }) = JsonArraySchema;

  /// Describes a value that may match any schema in [schemas].
  ///
  /// [dartType] is optional Dart-only metadata for generators and is not
  /// included in [toJson].
  const factory JsonSchema.anyOf(
    List<JsonSchema> schemas, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    DartSchemaType? dartType,
  }) = JsonAnyOfSchema;

  /// Describes a value that should match exactly one schema in [schemas].
  ///
  /// [dartType] is optional Dart-only metadata for generators and is not
  /// included in [toJson].
  const factory JsonSchema.oneOf(
    List<JsonSchema> schemas, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    DartSchemaType? dartType,
  }) = JsonOneOfSchema;

  /// Describes a value that should satisfy every schema in [schemas].
  ///
  /// [dartType] is optional Dart-only metadata for generators and is not
  /// included in [toJson].
  const factory JsonSchema.allOf(
    List<JsonSchema> schemas, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    DartSchemaType? dartType,
  }) = JsonAllOfSchema;

  /// Describes a JSON string.
  ///
  /// [format] is serialized as the JSON Schema `format` keyword. Dart Edge
  /// generators understand formats such as `date-time`, `binary`, `uuid`,
  /// `decimal`, and `int64` where relevant. [dartType] can bind the string to a
  /// richer Dart type, for example a string-backed extension type, without
  /// changing the serialized JSON Schema.
  const factory JsonSchema.string({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
    DartSchemaType? dartType,
  }) = JsonStringSchema;

  /// Describes a JSON integer.
  ///
  /// [format] is serialized as the JSON Schema `format` keyword. [minimum] and
  /// [maximum] are inclusive numeric bounds.
  const factory JsonSchema.integer({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
    num? minimum,
    num? maximum,
  }) = JsonIntegerSchema;

  /// Describes a JSON number.
  ///
  /// [format] is serialized as the JSON Schema `format` keyword. [minimum] and
  /// [maximum] are inclusive numeric bounds.
  const factory JsonSchema.number({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
    num? minimum,
    num? maximum,
  }) = JsonNumberSchema;

  /// Describes a JSON boolean.
  const factory JsonSchema.boolean({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
  }) = JsonBooleanSchema;

  /// Describes a JSON Schema `$ref`.
  ///
  /// [ref] is written verbatim, for example `#/components/schemas/UserDto`.
  const factory JsonSchema.ref(
    String ref, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
  }) = JsonReferenceSchema;

  /// Describes a `$ref` into the OpenAPI components schema registry.
  ///
  /// [schemaId] is expanded to `#/components/schemas/<schemaId>`.
  const factory JsonSchema.componentRef(
    String schemaId, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
  }) = JsonReferenceSchema.component;

  /// Wraps an already-built JSON Schema map.
  ///
  /// Prefer typed factories for generated Dart contracts. Use [raw] when a
  /// schema keyword is not represented by the typed model yet.
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
  ///
  /// Dart-only metadata such as [DartSchemaType] is intentionally omitted.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      r'$id': ?id,
      'title': ?title,
      'description': ?description,
      if (enumValues.isNotEmpty) 'enum': enumValues.toList(growable: false),
      ...toJsonKeywords(),
    };
  }

  /// Serializes the schema-specific JSON Schema keywords.
  ///
  /// Subclasses override this to add keywords such as `type`, `properties`,
  /// `items`, or `$ref`.
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

/// JSON Schema value that accepts any JSON value.
final class JsonAnySchema extends JsonSchema {
  /// Creates an unconstrained JSON Schema value.
  const JsonAnySchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
  }) : super._();

  @override
  Map<String, Object?> toJsonKeywords() => const <String, Object?>{};
}

/// JSON Schema object value.
final class JsonObjectSchema extends _JsonTypedSchema {
  /// Creates an object schema.
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

  /// Schemas keyed by JSON object field name.
  final Map<String, JsonSchema> properties;

  /// JSON object field names that must be present.
  final List<String> required;

  /// Whether fields outside [properties] are accepted.
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

/// JSON Schema array value.
final class JsonArraySchema extends _JsonTypedSchema {
  /// Creates an array schema.
  const JsonArraySchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.items,
  }) : super(type: JsonSchemaType.array);

  /// Schema applied to every array element.
  final JsonSchema? items;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{
      if (items case final items?) 'items': items.toJson(),
    };
  }
}

/// Base class for JSON Schema composition keywords.
sealed class JsonCompositeSchema extends JsonSchema {
  /// Creates a composite schema using [keyword].
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

  /// Candidate or constituent schemas used by the composition keyword.
  final List<JsonSchema> schemas;

  /// JSON Schema composition keyword, such as `anyOf`, `oneOf`, or `allOf`.
  final String keyword;

  /// Optional Dart-only type metadata for generators.
  final DartSchemaType? dartType;

  @override
  Map<String, Object?> toJsonKeywords() {
    return <String, Object?>{
      keyword: schemas.map((schema) => schema.toJson()).toList(),
      if (nullable) 'nullable': true,
    };
  }
}

/// JSON Schema `anyOf` composition.
final class JsonAnyOfSchema extends JsonCompositeSchema {
  /// Creates an `anyOf` schema.
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

/// JSON Schema `oneOf` composition.
final class JsonOneOfSchema extends JsonCompositeSchema {
  /// Creates a `oneOf` schema.
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

/// JSON Schema `allOf` composition.
final class JsonAllOfSchema extends JsonCompositeSchema {
  /// Creates an `allOf` schema.
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

/// JSON Schema string value.
final class JsonStringSchema extends _JsonTypedSchema {
  /// Creates a string schema.
  const JsonStringSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.format,
    this.dartType,
  }) : super(type: JsonSchemaType.string);

  /// Optional JSON Schema string `format`.
  final String? format;

  /// Optional Dart-only type metadata for string code generation.
  final DartSchemaType? dartType;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{'format': ?format};
  }
}

/// JSON Schema integer value.
final class JsonIntegerSchema extends _JsonTypedSchema {
  /// Creates an integer schema.
  const JsonIntegerSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.format,
    this.minimum,
    this.maximum,
  }) : super(type: JsonSchemaType.integer);

  /// Optional JSON Schema integer `format`.
  final String? format;

  /// Inclusive lower bound for accepted integer values.
  final num? minimum;

  /// Inclusive upper bound for accepted integer values.
  final num? maximum;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{
      'format': ?format,
      'minimum': ?minimum,
      'maximum': ?maximum,
    };
  }
}

/// JSON Schema number value.
final class JsonNumberSchema extends _JsonTypedSchema {
  /// Creates a number schema.
  const JsonNumberSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.format,
    this.minimum,
    this.maximum,
  }) : super(type: JsonSchemaType.number);

  /// Optional JSON Schema number `format`.
  final String? format;

  /// Inclusive lower bound for accepted number values.
  final num? minimum;

  /// Inclusive upper bound for accepted number values.
  final num? maximum;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{
      'format': ?format,
      'minimum': ?minimum,
      'maximum': ?maximum,
    };
  }
}

/// JSON Schema boolean value.
final class JsonBooleanSchema extends _JsonTypedSchema {
  /// Creates a boolean schema.
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

/// JSON Schema reference value.
final class JsonReferenceSchema extends JsonSchema {
  /// Creates a reference to [ref].
  const JsonReferenceSchema(
    this.ref, {
    super.id,
    super.title,
    super.description,
    super.enumValues,
  }) : super._();

  /// Creates a reference to an OpenAPI component schema.
  const JsonReferenceSchema.component(
    String schemaId, {
    super.id,
    super.title,
    super.description,
    super.enumValues,
  }) : ref = '#/components/schemas/$schemaId',
       super._();

  /// Reference target written to the `$ref` keyword.
  final String ref;

  @override
  Map<String, Object?> toJsonKeywords() => <String, Object?>{r'$ref': ref};
}

/// JSON Schema value backed by an existing JSON-compatible map.
final class JsonRawSchema extends JsonSchema {
  /// Creates a raw schema wrapper around [schema].
  const JsonRawSchema(this.schema, {super.id}) : super._();

  /// JSON-compatible schema map.
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
