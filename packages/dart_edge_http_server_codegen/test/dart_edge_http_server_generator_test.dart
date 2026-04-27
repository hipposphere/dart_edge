import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('DartEdgeHttpServerGenerator', () {
    test(
      'emits route options, schema registry, direct serializers, and client',
      () {
        final options = RouteOptions(
          operationId: 'createUser',
          summary: 'Create a user.',
          tags: const <String>['users'],
          headers: const JsonSchemaRef<Object?>('RequestHeaders'),
          body: RequestBody.json<Object?>(
            ref: const JsonSchemaRef<Object?>('CreateUserInput'),
          ),
          success: ResponseSpec.json<Object?>(
            status: 201,
            ref: const JsonSchemaRef<Object?>('UserDto'),
          ),
          errors: const <ErrorResponse>[
            ErrorResponse(status: 409, code: 'email_conflict'),
          ],
        );

        final source = const DartEdgeHttpServerGenerator().generate(
          DartEdgeHttpServerLibrarySpec(
            clientClassName: 'UsersClient',
            additionalImports: const ['package:example/models.dart'],
            schemas: const <JsonSchema>[
              JsonSchema.object(
                ref: JsonSchemaRef<Object?>('CreateUserInput'),
                properties: <String, JsonSchema>{
                  'name': JsonSchema.string(),
                  'email': JsonSchema.string(format: 'email'),
                },
                required: <String>['name', 'email'],
                nullable: false,
                additionalProperties: false,
              ),
              JsonSchema.object(
                ref: JsonSchemaRef<Object?>('UserDto'),
                properties: <String, JsonSchema>{
                  'id': JsonSchema.string(),
                  'name': JsonSchema.string(),
                  'email': JsonSchema.string(format: 'email'),
                },
                required: <String>['id', 'name', 'email'],
                nullable: false,
                additionalProperties: false,
              ),
            ],
            routes: [
              DartEdgeHttpRouteSpec(
                routeClassName: 'CreateUserRoute',
                method: HttpMethod.post,
                path: '/users',
                options: options,
                successType: 'UserDto',
                headersType: 'RequestHeaders',
                bodyType: 'CreateUserInput',
                inputs: const <DartEdgeRouteInputSpec>[
                  DartEdgeRouteInputSpec(
                    source: DartEdgeRouteInputSource.headers,
                    parameterName: 'requestId',
                    wireName: 'x-request-id',
                    dartType: 'String?',
                    required: false,
                  ),
                  DartEdgeRouteInputSpec(
                    source: DartEdgeRouteInputSource.body,
                    parameterName: 'body',
                    dartType: 'CreateUserInput',
                    required: true,
                  ),
                ],
              ),
            ],
          ),
        );

        expect(source, contains('final JsonSchemaRegistry \$generatedSchemas'));
        expect(source, contains('CreateUserRoute<TServices>'));
        expect(source, contains('CreateUserRoute(this.handler);'));
        expect(source, contains('final RouteOptions createUserRouteOptions'));
        expect(source, contains("operationId: 'createUser'"));
        expect(source, contains("JsonSchemaRef<Object?>('CreateUserInput')"));
        expect(source, isNot(contains('DartEdgeCodecRegistry')));
        expect(
          source,
          contains('CreateUserInput.fromJson(ctx.req.bodyOrNull)'),
        );
        expect(source, contains('void \$generatedRoutes<TServices>('));
        expect(source, contains('Router<TServices> router'));
        expect(source, contains("router.routePost('/users'"));
        expect(source, contains('final class UsersClient'));
        expect(source, contains('Future<UserDto> createUser({'));
        expect(
          source,
          contains(
            'invoke<UserDto, Never, Never, RequestHeaders?, CreateUserInput>',
          ),
        );
        expect(source, contains("schemaId: 'CreateUserInput'"));
        expect(source, contains("schemaId: 'UserDto'"));
        expect(source, contains('decoder: UserDto.fromJson'));
        expect(source, contains('encoder: (value) => value.toJson()'));
      },
    );
  });
}
