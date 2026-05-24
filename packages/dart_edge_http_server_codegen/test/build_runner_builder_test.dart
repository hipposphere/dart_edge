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

  final String? id;
  final String? title;
  final String? description;
  final List<Object?> enumValues;
  final bool nullable;
}

sealed class DartSchemaType {
  const DartSchemaType();

  const factory DartSchemaType.type(Type type) = DartConcreteSchemaType;
  const factory DartSchemaType.named(String name) = DartNamedSchemaType;
  const factory DartSchemaType.parameter(String name) = DartGenericSchemaType;
}

final class DartConcreteSchemaType extends DartSchemaType {
  const DartConcreteSchemaType(this.type);

  final Type type;
}

final class DartNamedSchemaType extends DartSchemaType {
  const DartNamedSchemaType(this.name);

  final String name;
}

final class DartGenericSchemaType extends DartSchemaType {
  const DartGenericSchemaType(this.name);

  final String name;
}

final class JsonAnySchema extends JsonSchema {
  const JsonAnySchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
  }) : super._();
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
    this.dartType,
  }) : super._();

  final String? format;
  final DartSchemaType? dartType;
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

final class JsonNumberSchema extends JsonSchema {
  const JsonNumberSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
    this.format,
  }) : super._();

  final String? format;
}

final class JsonBooleanSchema extends JsonSchema {
  const JsonBooleanSchema({
    super.id,
    super.title,
    super.description,
    super.enumValues,
    super.nullable = false,
  }) : super._();
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
}

final class JsonRawSchema extends JsonSchema {
  const JsonRawSchema(this.schema, {super.id}) : super._();

  final Map<String, Object?> schema;
}

final class JsonSchemaRegistry {
  const JsonSchemaRegistry({required this.schemas});

  final List<JsonSchema> schemas;
}

abstract interface class JsonEncodable {
  Object? toJson();
}

Map<String, Object?> readJsonObject(Object? value) {
  return Map<String, Object?>.from(value! as Map);
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
    'created_at': JsonSchema.string(format: 'date-time'),
    'deleted_at': JsonSchema.string(nullable: true, format: 'date-time'),
    'archived_at': JsonSchema.string(format: 'date-time'),
    'best_friend': JsonSchema.ref('#/components/schemas/FriendDto'),
    'manager': JsonSchema.ref('#/components/schemas/UserDto'),
  },
  required: <String>['name', 'tags', 'created_at'],
  additionalProperties: false,
);

const userSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[
    createUserInputSchema,
    userDtoSchema,
    friendDtoSchema,
    userListSchema,
  ],
);

const createUserBodySchema = JsonSchema.ref('#/components/schemas/CreateUserInput');

const userListSchema = JsonSchema.array(
  id: 'UserList',
  items: JsonSchema.ref('#/components/schemas/UserDto'),
);

const tagListSchema = JsonSchema.array(
  id: 'TagList',
  items: JsonSchema.string(),
);

const scoreListSchema = JsonSchema.array(
  id: 'ScoreList',
  items: JsonSchema.integer(),
);

const ratioListSchema = JsonSchema.array(
  id: 'RatioList',
  items: JsonSchema.number(),
);

const flagListSchema = JsonSchema.array(
  id: 'FlagList',
  items: JsonSchema.boolean(),
);

const tagMatrixSchema = JsonSchema.array(
  id: 'TagMatrix',
  items: JsonSchema.array(items: JsonSchema.string()),
);

const jsonListSchema = JsonSchema.array(
  id: 'JsonList',
  items: JsonSchema.any(),
);

const rawObjectListSchema = JsonSchema.array(
  id: 'RawObjectList',
  items: JsonSchema.raw({'type': 'object'}),
);

const publishStatusSchema = JsonSchema.string(
  id: 'PublishStatus',
  enumValues: <Object?>['draft', 'published', 'in-review'],
);

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

@FromSchema(userListSchema, registry: userSchemas)
typedef UserList = _$UserList;

@FromSchema(tagListSchema)
typedef TagList = _$TagList;

@FromSchema(scoreListSchema)
typedef ScoreList = _$ScoreList;

@FromSchema(ratioListSchema)
typedef RatioList = _$RatioList;

@FromSchema(flagListSchema)
typedef FlagList = _$FlagList;

@FromSchema(tagMatrixSchema)
typedef TagMatrix = _$TagMatrix;

@FromSchema(jsonListSchema)
typedef JsonList = _$JsonList;

@FromSchema(rawObjectListSchema)
typedef RawObjectList = _$RawObjectList;

@FromSchema(publishStatusSchema)
typedef PublishStatus = _$PublishStatus;
''',
        },
        generateFor: const {'test_app|lib/models.dart'},
        outputs: {
          'test_app|lib/models.dart_edge_http_server.g.part': decodedMatches(
            allOf([
              contains(
                'final class _\$CreateUserInput implements JsonEncodable',
              ),
              contains("static const schemaId = 'CreateUserInput';"),
              contains(
                'static const schemaRef = JsonSchema.componentRef(schemaId);',
              ),
              contains(
                'static const RequestBody requestBody = RequestBody.json(',
              ),
              contains('decoder: decode,'),
              contains(
                'static const ResponseSpec response = ResponseSpec.json(',
              ),
              contains('status: 200,'),
              contains('final String name;'),
              contains('final int? age;'),
              contains('final List<String> tags;'),
              contains('final DateTime createdAt;'),
              contains('final DateTime? deletedAt;'),
              contains('final DateTime? archivedAt;'),
              contains('final FriendDto? bestFriend;'),
              contains('final UserDto? manager;'),
              contains('@override'),
              contains('"name": name'),
              contains('"created_at": createdAt.toIso8601String()'),
              contains('"deleted_at": deletedAt?.toIso8601String()'),
              contains('"archived_at": archivedAt?.toIso8601String()'),
              contains('"best_friend": bestFriend?.toJson()'),
              contains('"manager": manager?.toJson()'),
              contains('name: json["name"]! as String'),
              contains('age: json["age"] as int?'),
              contains('tags: (json["tags"]! as List)'),
              contains(
                'createdAt: DateTime.parse(json["created_at"]! as String)',
              ),
              contains('deletedAt: json["deleted_at"] == null'),
              contains(': DateTime.parse(json["deleted_at"] as String)'),
              contains('archivedAt: json["archived_at"] == null'),
              contains(': DateTime.parse(json["archived_at"] as String)'),
              contains('bestFriend: json["best_friend"] == null'),
              contains(': FriendDto.fromJson('),
              contains(
                'Map<String, Object?>.from(json["best_friend"]! as Map),',
              ),
              contains('manager: json["manager"] == null'),
              contains(': UserDto.decode(json["manager"])'),
              contains(
                'final class _\$CreateUserBody implements JsonEncodable',
              ),
              contains("static const schemaId = 'CreateUserInput';"),
              contains('status: 201,'),
              contains('final String name;'),
              contains('final class _\$UserDto implements JsonEncodable'),
              contains("static const schemaId = 'UserDto';"),
              contains('extension type _\$UserList(List<UserDto> value)'),
              contains('implements List<UserDto>'),
              contains("static const schemaId = 'UserList';"),
              contains('static UserList decode(Object? value)'),
              contains(
                'List<Object?> toJson() => value.map((item) => item.toJson()).toList();',
              ),
              contains('static UserList fromJson(Object? value)'),
              contains('(value! as List).map((item) => UserDto.decode(item))'),
              contains('UserDto.decode(item)'),
              contains('extension type _\$TagList(List<String> value)'),
              contains('implements List<String>'),
              contains("static const schemaId = 'TagList';"),
              contains(
                '(value! as List).map((item) => item! as String).toList()',
              ),
              contains('extension type _\$ScoreList(List<int> value)'),
              contains('implements List<int>'),
              contains("static const schemaId = 'ScoreList';"),
              contains('(value! as List).map((item) => item! as int).toList()'),
              contains('extension type _\$RatioList(List<num> value)'),
              contains('implements List<num>'),
              contains("static const schemaId = 'RatioList';"),
              contains('(value! as List).map((item) => item! as num).toList()'),
              contains('extension type _\$FlagList(List<bool> value)'),
              contains('implements List<bool>'),
              contains("static const schemaId = 'FlagList';"),
              contains(
                '(value! as List).map((item) => item! as bool).toList()',
              ),
              contains('extension type _\$TagMatrix(List<List<String>> value)'),
              contains('implements List<List<String>>'),
              contains("static const schemaId = 'TagMatrix';"),
              contains(
                'value.map((item) => item.map((item) => item).toList()).toList()',
              ),
              contains(
                '(item) => (item! as List).map((item) => item! as String).toList()',
              ),
              contains('extension type _\$JsonList(List<Object?> value)'),
              contains('implements List<Object?>'),
              contains("static const schemaId = 'JsonList';"),
              contains(
                'extension type _\$RawObjectList(List<Map<String, Object?>> value)',
              ),
              contains('implements List<Map<String, Object?>>'),
              contains("static const schemaId = 'RawObjectList';"),
              contains('Map<String, Object?>.from(item! as Map)'),
              contains('enum _\$PublishStatus implements JsonEncodable'),
              contains("draft('draft'),"),
              contains("published('published'),"),
              contains("inReview('in-review');"),
              contains('final String value;'),
              contains('String toJson() => value;'),
              contains('static PublishStatus fromJson(Object? value)'),
              contains('"draft" => PublishStatus.draft'),
              contains('"in-review" => PublishStatus.inReview'),
              contains("static const schemaId = 'PublishStatus';"),
              isNot(contains('RouteOptions')),
              isNot(contains('\$generatedRoutes')),
            ]),
          ),
        },
      );
    });

    test('emits generic typed string models from FromSchema aliases', () async {
      final builder = dartEdgeHttpServerBuilder(BuilderOptions.empty);

      await testBuilder(
        builder,
        const <String, String>{
          'test_app|lib/ids.dart': r'''
// ignore_for_file: undefined_class

part 'ids.g.dart';

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
    DartSchemaType? dartType,
  }) = JsonStringSchema;

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

sealed class DartSchemaType {
  const DartSchemaType();

  const factory DartSchemaType.type(Type type) = DartConcreteSchemaType;
  const factory DartSchemaType.named(String name) = DartNamedSchemaType;
  const factory DartSchemaType.parameter(String name) = DartGenericSchemaType;
}

final class DartConcreteSchemaType extends DartSchemaType {
  const DartConcreteSchemaType(this.type);

  final Type type;
}

final class DartNamedSchemaType extends DartSchemaType {
  const DartNamedSchemaType(this.name);

  final String name;
}

final class DartGenericSchemaType extends DartSchemaType {
  const DartGenericSchemaType(this.name);

  final String name;
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
    this.dartType,
  }) : super._();

  final String? format;
  final DartSchemaType? dartType;
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

final class JsonSchemaRegistry {
  const JsonSchemaRegistry({required this.schemas});

  final List<JsonSchema> schemas;
}

final class SchemaRefModel {
  const SchemaRefModel(this.type, {this.schemaId});

  final Type type;
  final String? schemaId;
}

extension type DocumentId(String value) implements String {}

const idParamsSchema = JsonSchema.object(
  id: 'IdParams',
  properties: <String, JsonSchema>{
    'id': JsonSchema.string(dartType: DartSchemaType.parameter('TId')),
    'optional_id': JsonSchema.string(dartType: DartSchemaType.parameter('TId')),
    'items': JsonSchema.array(
      items: JsonSchema.object(
        properties: <String, JsonSchema>{
          'id': JsonSchema.string(dartType: DartSchemaType.parameter('TId')),
        },
        required: <String>['id'],
      ),
    ),
    'concrete_id': JsonSchema.string(
      dartType: DartSchemaType.named('DocumentId'),
    ),
  },
  required: <String>['id', 'items', 'concrete_id'],
  additionalProperties: false,
);

@FromSchema(idParamsSchema)
typedef IdParams<TId extends String> = _$IdParams<TId>;

@FromSchema(idParamsSchema)
typedef StringIdParams = _$StringIdParams;
''',
        },
        generateFor: const {'test_app|lib/ids.dart'},
        outputs: {
          'test_app|lib/ids.dart_edge_http_server.g.part': decodedMatches(
            allOf([
              contains(
                'final class _\$IdParams<TId extends String> implements JsonEncodable',
              ),
              contains('final TId id;'),
              contains('final TId? optionalId;'),
              contains('final List<Map<String, Object?>> items;'),
              contains('final DocumentId concreteId;'),
              contains(
                'static const RequestBody requestBody = RequestBody.json(',
              ),
              contains('factory _\$IdParams.decode(Object? value)'),
              contains('factory _\$IdParams.fromJson('),
              contains('id: json["id"]! as TId,'),
              contains('optionalId: json["optional_id"] as TId?,'),
              contains(
                '"id": (Map<String, Object?>.from(item! as Map))["id"]! as TId,',
              ),
              contains(
                'concreteId: DocumentId(json["concrete_id"]! as String),',
              ),
              contains(
                'final class _\$StringIdParams implements JsonEncodable',
              ),
              contains('final String id;'),
              contains('final String? optionalId;'),
              contains('decoder: decode,'),
              contains('id: json["id"]! as String,'),
            ]),
          ),
        },
      );
    });
  });
}
