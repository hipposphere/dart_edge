import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('DartEdgeHttpServerGenerator', () {
    test(
      'emits route contracts, schema registry, codec skeleton, and client',
      () {
        final contract = RouteContract(
          method: HttpMethod.post,
          path: '/users',
          options: RouteOptions(
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
          ),
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
            codecs: const <DartEdgeRuntimeCodecSpec>[
              DartEdgeRuntimeCodecSpec(
                schemaId: 'CreateUserInput',
                dartType: 'CreateUserInput',
              ),
              DartEdgeRuntimeCodecSpec(
                schemaId: 'UserDto',
                dartType: 'UserDto',
              ),
            ],
            routes: [
              DartEdgeHttpRouteSpec(
                routeClassName: 'CreateUserRoute',
                contract: contract,
                successType: 'UserDto',
                headersType: 'RequestHeaders',
                bodyType: 'CreateUserInput',
              ),
            ],
          ),
        );

        expect(source, contains('final JsonSchemaRegistry \$generatedSchemas'));
        expect(source, contains('CreateUserRoute<TServices>'));
        expect(source, contains('CreateUserRoute(this.handler);'));
        expect(source, contains('final RouteContract createUserRouteContract'));
        expect(source, contains("operationId: 'createUser'"));
        expect(source, contains("JsonSchemaRef<Object?>('CreateUserInput')"));
        expect(source, contains('DartEdgeCodecRegistry \$generatedCodecs({'));
        expect(source, contains("withCodec<UserDto>('UserDto', userDtoCodec)"));
        expect(
          source,
          contains('List<RouteDefinition<TServices>> \$generatedRoutes'),
        );
        expect(source, contains('final class UsersClient'));
        expect(source, contains('Future<UserDto> createUser({'));
        expect(source, contains("bodySchemaId: 'CreateUserInput'"));
        expect(source, contains("successSchemaId: 'UserDto'"));
      },
    );
  });
}
