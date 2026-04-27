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
final RouteOptions createUserRouteOptions = RouteOptions(
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
);
typedef _CreateUserRouteHandler<TServices> =
    FutureOr<UserDto> Function(CreateUserInput, String?);

final class CreateUserRoute<TServices>
    extends HttpRouteDefinition<TServices, UserDto> {
  CreateUserRoute(this.handler);

  final _CreateUserRouteHandler<TServices> handler;

  @override
  RouteOptions get options => createUserRouteOptions;

  @override
  FutureOr<UserDto> handle(RequestContext<TServices> ctx) {
    return handler(
      CreateUserInput.fromJson(ctx.req.bodyOrNull),
      ctx.req.header('x-request-id'),
    );
  }
}

void $generatedRoutes<TServices>(
  Router<TServices> router, {
  required _CreateUserRouteHandler<TServices> createUserRoute,
}) {
  router.routePost('/users', CreateUserRoute<TServices>(createUserRoute));
}

final class UsersClient extends DartEdgeGeneratedClientBase {
  UsersClient({
    required super.baseUri,
    required super.transport,
    super.defaultHeaders = const <String, String>{},
  });

  Future<UserDto> createUser({
    Map<String, Object?>? headers,
    required CreateUserInput body,
  }) {
    return invoke<
      UserDto,
      Never,
      Never,
      Map<String, Object?>?,
      CreateUserInput
    >(
      DartEdgeClientInvocation<
        UserDto,
        Never,
        Never,
        Map<String, Object?>?,
        CreateUserInput
      >(
        method: HttpMethod.post,
        pathTemplate: '/users',
        success: DartEdgeClientResponseSpec<UserDto>(
          status: 201,
          contentType: 'application/json; charset=utf-8',
          schemaId: 'UserDto',
          decoder: UserDto.fromJson,
        ),
        headers: DartEdgeClientRequestValue<Map<String, Object?>?>(
          schemaId: 'CreateUserHeaders',
          value: headers,
        ),
        body: DartEdgeClientRequestBody<CreateUserInput>(
          contentType: 'application/json; charset=utf-8',
          schemaId: 'CreateUserInput',
          value: body,
          encoder: (value) => value.toJson(),
        ),
      ),
    );
  }
}
