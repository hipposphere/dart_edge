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

  const factory JsonSchema.array({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    JsonSchema? items,
  }) = JsonArraySchema;

  const factory JsonSchema.string({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
  }) = JsonStringSchema;

  const factory JsonSchema.integer({
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
    bool nullable,
    String? format,
  }) = JsonIntegerSchema;

  const factory JsonSchema.ref(
    String ref, {
    String? id,
    String? title,
    String? description,
    List<Object?> enumValues,
  }) = JsonReferenceSchema;

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
    super.enumValues,
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
    super.enumValues,
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
    super.enumValues,
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
    super.enumValues,
  }) : super._();

  final String ref;
}

final class JsonSchemaRegistry {
  const JsonSchemaRegistry({required this.schemas});

  final List<JsonSchema> schemas;
}

abstract interface class JsonEncodable {
  Object? toJson();
}

typedef RequestBodyDecoder = Object? Function(Object? value);

final class RequestBody {
  const RequestBody._({this.schema, this.decoder});

  final JsonSchema? schema;
  final RequestBodyDecoder? decoder;

  const RequestBody.json({
    JsonSchema? schema,
    RequestBodyDecoder? decoder,
  }) : this._(schema: schema, decoder: decoder);
}

final class ResponseSpec {
  const ResponseSpec._({required this.status, this.schema});

  final int status;
  final JsonSchema? schema;

  const ResponseSpec.json({int status = 200, JsonSchema? schema})
    : this._(status: status, schema: schema);
}

final class FromSchema {
  const FromSchema(
    this.schema, {
    this.registry,
    this.refs = const [],
    this.responseStatus = 200,
  });

  final JsonSchema schema;
  final JsonSchemaRegistry? registry;
  final List<SchemaRefModel> refs;
  final int responseStatus;
}

final class SchemaRefModel {
  const SchemaRefModel(this.type, {this.schemaId});

  final Type type;
  final String? schemaId;
}

final class FriendDto implements JsonEncodable {
  const FriendDto({required this.id});

  factory FriendDto.fromJson(Map<String, Object?> json) {
    return FriendDto(id: json['id']! as String);
  }

  final String id;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'id': id};
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

const friendDtoSchema = JsonSchema.object(
  id: 'FriendDto',
  properties: <String, JsonSchema>{
    'id': JsonSchema.string(),
  },
  required: <String>['id'],
  additionalProperties: false,
);

const createUserInputSchema = JsonSchema.object(
  id: 'CreateUserInput',
  properties: <String, JsonSchema>{
    'name': JsonSchema.string(),
    'age': JsonSchema.integer(),
    'status': JsonSchema.string(enumValues: ['draft', 'published']),
    'tags': JsonSchema.array(items: JsonSchema.string()),
    'best_friend': JsonSchema.ref('FriendDto'),
    'manager': JsonSchema.ref('UserDto'),
  },
  required: <String>['name', 'tags'],
  additionalProperties: false,
);

const userSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[createUserInputSchema, userDtoSchema, friendDtoSchema],
);

const createUserBodySchema = JsonSchema.ref('CreateUserInput');

@FromSchema(
  createUserInputSchema,
  registry: userSchemas,
  refs: [SchemaRefModel(FriendDto)],
)
typedef CreateUserInput = _$CreateUserInput;

@FromSchema(
  createUserBodySchema,
  registry: userSchemas,
  refs: [SchemaRefModel(FriendDto)],
  responseStatus: 201,
)
typedef CreateUserBody = _$CreateUserBody;

@FromSchema(userDtoSchema, registry: userSchemas)
typedef UserDto = _$UserDto;
''',
        },
        generateFor: const {'test_app|lib/models.dart'},
        outputs: {
          'test_app|lib/models.dart_edge_http_server.g.part': decodedMatches(
            allOf([
              contains(
                'final class _\$CreateUserInput implements JsonEncodable',
              ),
              contains('static const schemaId = "CreateUserInput";'),
              contains('static const schemaRef = JsonSchema.ref(schemaId);'),
              contains(
                'static const RequestBody requestBody = RequestBody.json(',
              ),
              contains('decoder: fromJson,'),
              contains(
                'static const ResponseSpec response = ResponseSpec.json(',
              ),
              contains('status: 200,'),
              contains('final String name;'),
              contains('final int? age;'),
              contains('final List<String> tags;'),
              contains('final FriendDto? bestFriend;'),
              contains('final UserDto? manager;'),
              contains('@override'),
              contains('"name": name'),
              contains('"best_friend": bestFriend?.toJson()'),
              contains('"manager": manager?.toJson()'),
              contains('name: json["name"]! as String'),
              contains('age: json["age"] as int?'),
              contains('bestFriend: json["best_friend"] == null'),
              contains(': FriendDto.fromJson('),
              contains(
                'Map<String, Object?>.from(json["best_friend"]! as Map),',
              ),
              contains('manager: json["manager"] == null'),
              contains(': UserDto.fromJson(json["manager"])'),
              contains(
                'final class _\$CreateUserBody implements JsonEncodable',
              ),
              contains('static const schemaId = "CreateUserInput";'),
              contains('status: 201,'),
              contains('final String name;'),
              contains('final class _\$UserDto implements JsonEncodable'),
              contains('static const schemaId = "UserDto";'),
              isNot(contains('RouteOptions')),
              isNot(contains('\$generatedRoutes')),
            ]),
          ),
        },
      );
    });
  });
}
