import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:json_schema_gen/builder.dart';
import 'package:test/test.dart';

void main() {
  test('generates a plain JSON model without Dart Edge contracts', () async {
    await testBuilder(
      jsonSchemaBuilder(BuilderOptions.empty),
      const <String, String>{
        'test_app|lib/model.dart': r'''
part 'model.g.dart';

sealed class JsonSchema {
  const JsonSchema._({
    this.id,
    this.title,
    this.description,
    this.enumValues = const <Object?>[],
    this.nullable = false,
  });

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

  const factory JsonSchema.string({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
  }) = JsonStringSchema;

  final String? id;
  final String? title;
  final String? description;
  final List<Object?> enumValues;
  final bool nullable;
}

final class JsonObjectSchema extends JsonSchema {
  const JsonObjectSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable,
    this.properties = const <String, JsonSchema>{},
    this.required = const <String>[],
    this.additionalProperties,
  }) : super._();

  final Map<String, JsonSchema> properties;
  final List<String> required;
  final bool? additionalProperties;
}

final class JsonStringSchema extends JsonSchema {
  const JsonStringSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable,
  }) : super._();
}

final class FromSchema {
  const FromSchema(this.schema, {this.registry, this.refs = const []});
  final JsonSchema schema;
  final Object? registry;
  final List<Object> refs;
}

const userSchema = JsonSchema.object(
  id: 'User',
  properties: <String, JsonSchema>{'id': JsonSchema.string()},
  required: <String>['id'],
);

@FromSchema(userSchema)
typedef User = _$User;
''',
      },
      outputs: <String, Matcher>{
        'test_app|lib/model.json_schema.g.part': decodedMatches(
          allOf(
            contains('static const JsonSchema schema'),
            contains('Map<String, Object?> toJson()'),
            isNot(contains('RequestBody')),
            isNot(contains('ResponseSpec')),
            isNot(contains('JsonEncodable')),
            isNot(contains('@override')),
          ),
        ),
      },
    );
  });
}
