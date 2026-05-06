import 'dart:convert';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:test/test.dart';

void main() {
  group('DartEdgeClientGenerator', () {
    test('emits a client class from route metadata', () {
      final source = const DartEdgeClientGenerator().generate(
        DartEdgeClientLibrarySpec(
          className: 'UsersClient',
          additionalImports: const ['package:example/models.dart'],
          operations: [
            DartEdgeClientOperation(
              method: HttpMethod.get,
              path: '/users/<id>',
              options: RouteOptions(
                operationId: 'getUser',
                params: const JsonSchema.ref('UserPath'),
                query: const JsonSchema.ref('GetUserQuery'),
                success: ResponseSpec.json(
                  schema: const JsonSchema.ref('UserDto'),
                ),
              ),
              successType: 'UserDto',
              paramsType: 'UserPath',
              queryType: 'GetUserQuery',
            ),
          ],
        ),
      );

      expect(source, contains('final class UsersClient'));
      expect(source, contains('Future<UserDto> getUser({'));
      expect(source, contains("pathTemplate: '/users/<id>'"));
      expect(
        source,
        contains('invoke<UserDto, UserPath, GetUserQuery?, Never, Never>'),
      );
      expect(source, contains("schemaId: 'UserPath'"));
      expect(source, contains("schemaId: 'GetUserQuery'"));
      expect(source, contains("schemaId: 'UserDto'"));
      expect(source, contains("import 'package:example/models.dart';"));
    });

    test('does not use inline schema ids as serializer targets', () {
      final source = const DartEdgeClientGenerator().generate(
        DartEdgeClientLibrarySpec(
          className: 'UsersClient',
          operations: [
            DartEdgeClientOperation(
              method: HttpMethod.post,
              path: '/users',
              options: RouteOptions(
                operationId: 'createUser',
                body: RequestBody.json(
                  schema: const JsonSchema.object(id: 'CreateUserBody'),
                ),
                success: ResponseSpec.json(
                  schema: const JsonSchema.object(id: 'UserDto'),
                ),
              ),
              successType: 'UserDto',
              bodyType: 'CreateUserBody',
            ),
          ],
        ),
      );

      expect(source, isNot(contains("schemaId: 'CreateUserBody'")));
      expect(source, isNot(contains("schemaId: 'UserDto'")));
      expect(source, isNot(contains('decoder: UserDto.fromJson')));
      expect(source, isNot(contains('encoder: (value) => value.toJson()')));
    });
  });

  group('DartEdgeGeneratedClientBase', () {
    test(
      'builds requests and decodes responses via generated serializers',
      () async {
        final transport = _FakeTransport(
          onSend: (request) async {
            expect(request.method, HttpMethod.post);
            expect(
              request.uri,
              Uri.parse(
                'https://api.example.test/v1/users/42'
                '?includeDeleted=true'
                '&tags=alpha'
                '&tags=beta',
              ),
            );
            expect(request.headers, {
              'x-api-key': 'secret',
              'x-request-id': 'req_1',
              'content-type': 'application/json; charset=utf-8',
            });
            expect(jsonDecode(request.body!), {'name': 'Ada'});

            return DartEdgeClientResponse(
              status: 201,
              contentType: 'application/json; charset=utf-8',
              body: jsonEncode({'id': '42', 'name': 'Ada'}),
            );
          },
        );
        final client = _TestClient(
          baseUri: Uri.parse('https://api.example.test/v1'),
          transport: transport,
          defaultHeaders: const {'x-api-key': 'secret'},
        );

        final response = await client
            .invoke<
              UserDto,
              UserPath,
              UserQuery,
              RequestHeaders,
              CreateUserBody
            >(
              const DartEdgeClientInvocation<
                UserDto,
                UserPath,
                UserQuery,
                RequestHeaders,
                CreateUserBody
              >(
                method: HttpMethod.post,
                pathTemplate: '/users/<id>',
                success: DartEdgeClientResponseSpec<UserDto>(
                  status: 201,
                  contentType: 'application/json; charset=utf-8',
                  schemaId: 'UserDto',
                  decoder: UserDto.fromJson,
                ),
                params: DartEdgeClientRequestValue<UserPath>(
                  schemaId: 'UserPath',
                  value: UserPath(id: '42'),
                  encoder: UserPath.toJson,
                ),
                query: DartEdgeClientRequestValue<UserQuery>(
                  schemaId: 'UserQuery',
                  value: UserQuery(
                    includeDeleted: true,
                    tags: ['alpha', 'beta'],
                  ),
                  encoder: UserQuery.toJson,
                ),
                headers: DartEdgeClientRequestValue<RequestHeaders>(
                  schemaId: 'RequestHeaders',
                  value: RequestHeaders(requestId: 'req_1'),
                  encoder: RequestHeaders.toJson,
                ),
                body: DartEdgeClientRequestBody<CreateUserBody>(
                  contentType: 'application/json; charset=utf-8',
                  schemaId: 'CreateUserBody',
                  value: CreateUserBody(name: 'Ada'),
                  encoder: CreateUserBody.toJson,
                ),
              ),
            );

        expect(response, const UserDto(id: '42', name: 'Ada'));
      },
    );
  });
}

final class _TestClient extends DartEdgeGeneratedClientBase {
  const _TestClient({
    required super.baseUri,
    required super.transport,
    super.defaultHeaders,
  });
}

final class _FakeTransport implements DartEdgeClientTransport {
  const _FakeTransport({required this.onSend});

  final Future<DartEdgeClientResponse> Function(DartEdgeClientRequest request)
  onSend;

  @override
  Future<DartEdgeClientResponse> send(DartEdgeClientRequest request) {
    return onSend(request);
  }
}

final class UserPath {
  const UserPath({required this.id});

  final String id;

  static Map<String, Object?> toJson(UserPath value) => {'id': value.id};
}

final class UserQuery {
  const UserQuery({required this.includeDeleted, required this.tags});

  final bool includeDeleted;
  final List<String> tags;

  static Map<String, Object?> toJson(UserQuery value) => {
    'includeDeleted': value.includeDeleted,
    'tags': value.tags,
  };
}

final class RequestHeaders {
  const RequestHeaders({required this.requestId});

  final String requestId;

  static Map<String, Object?> toJson(RequestHeaders value) => {
    'x-request-id': value.requestId,
  };
}

final class CreateUserBody {
  const CreateUserBody({required this.name});

  final String name;

  static Map<String, Object?> toJson(CreateUserBody value) => {
    'name': value.name,
  };
}

final class UserDto {
  const UserDto({required this.id, required this.name});

  final String id;
  final String name;

  static UserDto fromJson(Object? value) {
    final map = value! as Map<String, Object?>;
    return UserDto(id: map['id']! as String, name: map['name']! as String);
  }

  @override
  bool operator ==(Object other) {
    return other is UserDto && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}
