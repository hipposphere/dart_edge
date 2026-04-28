import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_edge_http_server_codegen/builder.dart';
import 'package:test/test.dart';

void main() {
  group('dartEdgeHttpServerBuilder', () {
    test('emits model classes from FromSchema type aliases', () async {
      final builder = dartEdgeHttpServerBuilder(BuilderOptions.empty);

      await testBuilder(
        builder,
        const <String, String>{
          'test_app|lib/models.dart': r'''
// ignore_for_file: undefined_class

part 'models.g.dart';

sealed class JsonSchema {
  const JsonSchema._({
    this.id,
    this.title,
    this.description,
    this.nullable = false,
  });

  const factory JsonSchema.object({
    String? id,
    String? title,
    String? description,
    bool nullable,
    Map<String, JsonSchema> properties,
    List<String> required,
    bool? additionalProperties,
  }) = JsonObjectSchema;

  const factory JsonSchema.array({
    String? id,
    String? title,
    String? description,
    bool nullable,
    JsonSchema? items,
  }) = JsonArraySchema;

  const factory JsonSchema.string({
    String? id,
    String? title,
    String? description,
    bool nullable,
    String? format,
  }) = JsonStringSchema;

  const factory JsonSchema.integer({
    String? id,
    String? title,
    String? description,
    bool nullable,
    String? format,
  }) = JsonIntegerSchema;

  const factory JsonSchema.ref(
    String ref, {
    String? id,
    String? title,
    String? description,
  }) = JsonReferenceSchema;

  final String? id;
  final String? title;
  final String? description;
  final bool nullable;
}

final class JsonObjectSchema extends JsonSchema {
  const JsonObjectSchema({
    super.id,
    super.title,
    super.description,
    super.nullable = false,
    this.properties = const <String, JsonSchema>{},
    this.required = const <String>[],
    this.additionalProperties,
  }) : super._();

  final Map<String, JsonSchema> properties;
  final List<String> required;
  final bool? additionalProperties;
}

final class JsonArraySchema extends JsonSchema {
  const JsonArraySchema({
    super.id,
    super.title,
    super.description,
    super.nullable = false,
    this.items,
  }) : super._();

  final JsonSchema? items;
}

final class JsonStringSchema extends JsonSchema {
  const JsonStringSchema({
    super.id,
    super.title,
    super.description,
    super.nullable = false,
    this.format,
  }) : super._();

  final String? format;
}

final class JsonIntegerSchema extends JsonSchema {
  const JsonIntegerSchema({
    super.id,
    super.title,
    super.description,
    super.nullable = false,
    this.format,
  }) : super._();

  final String? format;
}

final class JsonReferenceSchema extends JsonSchema {
  const JsonReferenceSchema(
    this.ref, {
    super.id,
    super.title,
    super.description,
  }) : super._();

  final String ref;
}

final class JsonSchemaRegistry {
  const JsonSchemaRegistry({required this.schemas});

  final List<JsonSchema> schemas;
}

final class JsonSchemaRef<T> {
  const JsonSchemaRef(this.id);

  final String id;
}

final class FromSchema {
  const FromSchema(this.schema, {this.registry});

  final JsonSchema schema;
  final JsonSchemaRegistry? registry;
}

const userDtoSchema = JsonSchema.object(
  id: 'UserDto',
  properties: <String, JsonSchema>{
    'id': JsonSchema.string(),
    'email': JsonSchema.string(format: 'email'),
  },
  required: <String>['id', 'email'],
  additionalProperties: false,
);

const createUserInputSchema = JsonSchema.object(
  id: 'CreateUserInput',
  properties: <String, JsonSchema>{
    'name': JsonSchema.string(),
    'age': JsonSchema.integer(),
    'tags': JsonSchema.array(items: JsonSchema.string()),
    'best_friend': JsonSchema.ref('UserDto'),
  },
  required: <String>['name', 'tags'],
  additionalProperties: false,
);

const userSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[createUserInputSchema, userDtoSchema],
);

@FromSchema(createUserInputSchema, registry: userSchemas)
typedef CreateUserInput = _$CreateUserInput;

@FromSchema(userDtoSchema, registry: userSchemas)
typedef UserDto = _$UserDto;
''',
        },
        generateFor: const {'test_app|lib/models.dart'},
        outputs: {
          'test_app|lib/models.dart_edge_http_server.g.part': decodedMatches(
            allOf([
              contains('final class _\$CreateUserInput'),
              contains(
                'static const schemaRef = '
                'JsonSchemaRef<CreateUserInput>("CreateUserInput");',
              ),
              contains('final String name;'),
              contains('final int? age;'),
              contains('final List<String> tags;'),
              contains('final UserDto? bestFriend;'),
              contains('"name": name'),
              contains('"best_friend": bestFriend?.toJson()'),
              contains('name: json["name"]! as String'),
              contains('age: json["age"] as int?'),
              contains('bestFriend: json["best_friend"] == null'),
              contains(': UserDto.fromJson(json["best_friend"])'),
              contains('final class _\$UserDto'),
              contains(
                'static const schemaRef = JsonSchemaRef<UserDto>("UserDto");',
              ),
              isNot(contains('RouteOptions')),
              isNot(contains('\$generatedRoutes')),
            ]),
          ),
        },
      );
    });
  });
}
