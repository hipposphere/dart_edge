import 'json_schema_ref.dart';

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

/// Typed JSON Schema model used by route metadata and installed registries.
sealed class JsonSchema {
  const JsonSchema._({
    this.ref,
    this.title,
    this.description,
    this.nullable = false,
  });

  const factory JsonSchema.any({
    JsonSchemaRef<Object?>? ref,
    String? title,
    String? description,
  }) = JsonAnySchema;

  const factory JsonSchema.object({
    JsonSchemaRef<Object?>? ref,
    String? title,
    String? description,
    bool nullable,
    Map<String, JsonSchema> properties,
    List<String> required,
    bool? additionalProperties,
  }) = JsonObjectSchema;

  const factory JsonSchema.array({
    JsonSchemaRef<Object?>? ref,
    String? title,
    String? description,
    bool nullable,
    JsonSchema? items,
  }) = JsonArraySchema;

  const factory JsonSchema.string({
    JsonSchemaRef<Object?>? ref,
    String? title,
    String? description,
    bool nullable,
    String? format,
  }) = JsonStringSchema;

  const factory JsonSchema.integer({
    JsonSchemaRef<Object?>? ref,
    String? title,
    String? description,
    bool nullable,
    String? format,
  }) = JsonIntegerSchema;

  const factory JsonSchema.number({
    JsonSchemaRef<Object?>? ref,
    String? title,
    String? description,
    bool nullable,
    String? format,
  }) = JsonNumberSchema;

  const factory JsonSchema.boolean({
    JsonSchemaRef<Object?>? ref,
    String? title,
    String? description,
    bool nullable,
  }) = JsonBooleanSchema;

  const factory JsonSchema.ref(
    String ref, {
    String? title,
    String? description,
  }) = JsonReferenceSchema;

  const factory JsonSchema.raw(
    Map<String, Object?> schema, {
    JsonSchemaRef<Object?>? ref,
  }) = JsonRawSchema;

  /// Optional stable id for top-level installed schemas.
  final JsonSchemaRef<Object?>? ref;

  /// Optional human-readable schema title.
  final String? title;

  /// Optional human-readable schema description.
  final String? description;

  /// Whether this schema also allows JSON `null`.
  final bool nullable;

  /// Convenience alias for `ref.id`.
  String? get id => ref?.id;

  /// Serializes this schema into a JSON-compatible map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (id case final id?) r'$id': id,
      if (title case final title?) 'title': title,
      if (description case final description?) 'description': description,
      ...toJsonKeywords(),
    };
  }

  Map<String, Object?> toJsonKeywords();
}

abstract base class _JsonTypedSchema extends JsonSchema {
  const _JsonTypedSchema({
    required this.type,
    super.ref,
    super.title,
    super.description,
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
  const JsonAnySchema({super.ref, super.title, super.description}) : super._();

  @override
  Map<String, Object?> toJsonKeywords() => const <String, Object?>{};
}

final class JsonObjectSchema extends _JsonTypedSchema {
  const JsonObjectSchema({
    super.ref,
    super.title,
    super.description,
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
      if (additionalProperties case final additionalProperties?)
        'additionalProperties': additionalProperties,
    };
  }
}

final class JsonArraySchema extends _JsonTypedSchema {
  const JsonArraySchema({
    super.ref,
    super.title,
    super.description,
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

final class JsonStringSchema extends _JsonTypedSchema {
  const JsonStringSchema({
    super.ref,
    super.title,
    super.description,
    super.nullable = false,
    this.format,
  }) : super(type: JsonSchemaType.string);

  final String? format;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{if (format case final format?) 'format': format};
  }
}

final class JsonIntegerSchema extends _JsonTypedSchema {
  const JsonIntegerSchema({
    super.ref,
    super.title,
    super.description,
    super.nullable = false,
    this.format,
  }) : super(type: JsonSchemaType.integer);

  final String? format;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{if (format case final format?) 'format': format};
  }
}

final class JsonNumberSchema extends _JsonTypedSchema {
  const JsonNumberSchema({
    super.ref,
    super.title,
    super.description,
    super.nullable = false,
    this.format,
  }) : super(type: JsonSchemaType.number);

  final String? format;

  @override
  Map<String, Object?> additionalKeywords() {
    return <String, Object?>{if (format case final format?) 'format': format};
  }
}

final class JsonBooleanSchema extends _JsonTypedSchema {
  const JsonBooleanSchema({
    super.ref,
    super.title,
    super.description,
    super.nullable = false,
  }) : super(type: JsonSchemaType.boolean);

  @override
  Map<String, Object?> additionalKeywords() => const <String, Object?>{};
}

final class JsonReferenceSchema extends JsonSchema {
  const JsonReferenceSchema(this.targetRef, {super.title, super.description})
    : super._();

  final String targetRef;

  @override
  Map<String, Object?> toJsonKeywords() => <String, Object?>{
    r'$ref': targetRef,
  };
}

final class JsonRawSchema extends JsonSchema {
  const JsonRawSchema(this.schema, {super.ref}) : super._();

  final Map<String, Object?> schema;

  @override
  String? get title => _stringValue('title');

  @override
  String? get description => _stringValue('description');

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{...schema, if (id case final id?) r'$id': id};
  }

  @override
  Map<String, Object?> toJsonKeywords() => schema;

  String? _stringValue(String key) {
    final value = schema[key];
    return value is String ? value : null;
  }
}
