// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'typed_routes_example.dart';

// **************************************************************************
// DartEdgeHttpServerBuilderGenerator
// **************************************************************************

final JsonSchemaRegistry $generatedSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[
    JsonSchema.object(
      ref: const JsonSchemaRef<Object?>('CreateUserHeaders'),
      nullable: false,
      properties: <String, JsonSchema>{
        'x-request-id': JsonSchema.string(nullable: true),
      },
      required: <String>['x-request-id'],
      additionalProperties: false,
    ),
    JsonSchema.object(
      ref: const JsonSchemaRef<Object?>('CreateUserInput'),
      nullable: false,
      properties: <String, JsonSchema>{
        'name': JsonSchema.string(nullable: false),
        'email': JsonSchema.string(nullable: false),
      },
      required: <String>['name', 'email'],
      additionalProperties: false,
    ),
    JsonSchema.object(
      ref: const JsonSchemaRef<Object?>('UserDto'),
      nullable: false,
      properties: <String, JsonSchema>{
        'id': JsonSchema.string(nullable: false),
        'name': JsonSchema.string(nullable: false),
        'email': JsonSchema.string(nullable: false),
      },
      required: <String>['id', 'name', 'email'],
      additionalProperties: false,
    ),
  ],
);
DartEdgeCodecRegistry $generatedCodecs({
  required DartEdgeCodec<CreateUserInput> createUserInputCodec,
  required DartEdgeCodec<UserDto> userDtoCodec,
}) {
  return DartEdgeCodecRegistry.empty
      .withCodec<CreateUserInput>('CreateUserInput', createUserInputCodec)
      .withCodec<UserDto>('UserDto', userDtoCodec);
}

final RouteContract createUserRouteContract = RouteContract(
  method: HttpMethod.post,
  path: '/users',
  options: RouteOptions(
    operationId: 'createUser',
    summary: 'Create a user.',
    tags: <String>['users'],
    headers: const JsonSchemaRef<Object?>('CreateUserHeaders'),
    body: RequestBody.json<Object?>(
      ref: const JsonSchemaRef<Object?>('CreateUserInput'),
    ),
    success: ResponseSpec.json<Object?>(
      status: 201,
      ref: const JsonSchemaRef<Object?>('UserDto'),
    ),
  ),
);
typedef _CreateUserRouteHandler<TServices> =
    FutureOr<UserDto> Function(RequestContext<TServices>);

final class CreateUserRoute<TServices>
    extends JsonRouteDefinition<TServices, UserDto> {
  CreateUserRoute(this.handler);

  final _CreateUserRouteHandler<TServices> handler;

  @override
  RouteContract get contract => createUserRouteContract;

  @override
  FutureOr<UserDto> handle(RequestContext<TServices> ctx) {
    return handler(ctx);
  }
}

List<RouteDefinition<TServices>> $generatedRoutes<TServices>({
  required _CreateUserRouteHandler<TServices> createUserRoute,
}) {
  return <RouteDefinition<TServices>>[
    CreateUserRoute<TServices>(createUserRoute),
  ];
}

final class UsersClient extends DartEdgeGeneratedClientBase {
  UsersClient({
    required super.baseUri,
    required super.transport,
    super.codecs = DartEdgeClientCodecRegistry.empty,
    super.defaultHeaders = const <String, String>{},
  });

  Future<UserDto> createUser({
    Map<String, Object?>? headers,
    required CreateUserInput body,
  }) {
    return invoke<UserDto>(
      method: HttpMethod.post,
      pathTemplate: '/users',
      successStatus: 201,
      successContentType: 'application/json; charset=utf-8',
      successSchemaId: 'UserDto',
      headersSchemaId: 'CreateUserHeaders',
      headers: headers,
      requestContentType: 'application/json; charset=utf-8',
      bodySchemaId: 'CreateUserInput',
      body: body,
    );
  }
}
