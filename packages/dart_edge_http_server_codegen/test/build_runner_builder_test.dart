import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_edge_http_server_codegen/builder.dart';
import 'package:test/test.dart';

void main() {
  group('dartEdgeHttpServerBuilder', () {
    test('emits a shared part from annotated route functions', () async {
      final builder = dartEdgeHttpServerBuilder(
        BuilderOptions(const <String, Object?>{
          'client_class_name': 'UsersClient',
        }),
      );

      await testBuilder(
        builder,
        const <String, String>{
          'test_app|lib/users.dart': r'''
part 'users.g.dart';

enum HttpMethod { get, post, put, patch, delete, head, options }

final class TypedJsonRoute {
  const TypedJsonRoute({
    required this.method,
    required this.path,
    required this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
  });

  final HttpMethod method;
  final String path;
  final String operationId;
  final String? summary;
  final List<String> tags;
  final bool deprecated;
}

final class RouteBody {
  const RouteBody({this.contentType = 'application/json'});

  final String contentType;
}

final class PathParam {
  const PathParam([this.name]);

  final String? name;
}

final class QueryParam {
  const QueryParam([this.name]);

  final String? name;
}

final class HeaderParam {
  const HeaderParam(this.name);

  final String name;
}

final class SuccessResponse {
  const SuccessResponse({
    this.status = 200,
    this.contentType = 'application/json',
  });

  final int status;
  final String contentType;
}

final class RouteErrorResponse {
  const RouteErrorResponse(
    this.status, {
    this.code,
    this.contentType = 'application/json',
  });

  final int status;
  final String? code;
  final String contentType;
}

@TypedJsonRoute(
  method: HttpMethod.post,
  path: '/users/<id>',
  operationId: 'createUser',
  summary: 'Create a user.',
  tags: <String>['users'],
)
@SuccessResponse(status: 201)
@RouteErrorResponse(409, code: 'email_conflict')
Future<UserDto> createUser(
  @PathParam('id') String id,
  @QueryParam('notify') bool? notify,
  @HeaderParam('x-request-id') String requestId,
  @RouteBody() CreateUserInput body,
) async {
  return UserDto(id: id, name: body.name, email: body.email);
}

final class CreateUserInput {
  const CreateUserInput({required this.name, required this.email});

  final String name;
  final String email;
}

final class UserDto {
  const UserDto({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;
}
''',
        },
        generateFor: const {'test_app|lib/users.dart'},
        outputs: {
          'test_app|lib/users.dart_edge_http_server.g.part': decodedMatches(
            allOf([
              isNot(contains('part of')),
              contains('final JsonSchemaRegistry \$generatedSchemas'),
              contains('final RouteOptions createUserRouteOptions'),
              contains("path: '/users/<id>'"),
              contains(
                "params: const JsonSchemaRef<Object?>('CreateUserParams')",
              ),
              contains(
                "query: const JsonSchemaRef<Object?>('CreateUserQuery')",
              ),
              contains(
                "headers: const JsonSchemaRef<Object?>('CreateUserHeaders')",
              ),
              contains("JsonSchemaRef<Object?>('CreateUserInput')"),
              contains("JsonSchemaRef<Object?>('UserDto')"),
              isNot(contains('DartEdgeCodecRegistry \$generatedCodecs({')),
              contains('CreateUserInput.fromJson(ctx.req.bodyOrNull)'),
              contains('decoder: UserDto.fromJson'),
              contains('encoder: (value) => value.toJson()'),
              contains('CreateUserRoute<TServices>'),
              contains('List<RouteDefinition<TServices>> \$generatedRoutes'),
              contains('final class UsersClient'),
              contains('Future<UserDto> createUser({'),
            ]),
          ),
        },
      );
    });
  });
}
