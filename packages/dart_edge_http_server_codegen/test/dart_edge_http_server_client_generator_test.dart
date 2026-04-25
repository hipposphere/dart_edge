import 'dart:convert';

import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';
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
              contract: RouteContract(
                method: HttpMethod.get,
                path: '/users/<id>',
                options: RouteOptions(
                  operationId: 'getUser',
                  params: const JsonSchemaRef<Object?>('UserPath'),
                  query: const JsonSchemaRef<Object?>('GetUserQuery'),
                  success: ResponseSpec.json<Object?>(
                    ref: const JsonSchemaRef<Object?>('UserDto'),
                  ),
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
      expect(source, contains("paramsSchemaId: 'UserPath'"));
      expect(source, contains("querySchemaId: 'GetUserQuery'"));
      expect(source, contains("successSchemaId: 'UserDto'"));
      expect(source, contains("import 'package:example/models.dart';"));
    });
  });

  group('DartEdgeGeneratedClientBase', () {
    test('builds requests and decodes responses via schema codecs', () async {
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
        codecs: DartEdgeClientCodecRegistry.empty
            .withCodec<UserPath>(
              'UserPath',
              DartEdgeClientCodec(
                encode: (value) => {'id': value.id},
                decode: (_) => throw UnimplementedError(),
              ),
            )
            .withCodec<UserQuery>(
              'UserQuery',
              DartEdgeClientCodec(
                encode: (value) => {
                  'includeDeleted': value.includeDeleted,
                  'tags': value.tags,
                },
                decode: (_) => throw UnimplementedError(),
              ),
            )
            .withCodec<RequestHeaders>(
              'RequestHeaders',
              DartEdgeClientCodec(
                encode: (value) => {'x-request-id': value.requestId},
                decode: (_) => throw UnimplementedError(),
              ),
            )
            .withCodec<CreateUserBody>(
              'CreateUserBody',
              DartEdgeClientCodec(
                encode: (value) => {'name': value.name},
                decode: (_) => throw UnimplementedError(),
              ),
            )
            .withCodec<UserDto>(
              'UserDto',
              DartEdgeClientCodec(
                encode: (value) => {'id': value.id, 'name': value.name},
                decode: (json) {
                  final map = json! as Map<String, Object?>;
                  return UserDto(
                    id: map['id']! as String,
                    name: map['name']! as String,
                  );
                },
              ),
            ),
      );

      final response = await client.invoke<UserDto>(
        method: HttpMethod.post,
        pathTemplate: '/users/<id>',
        successStatus: 201,
        successContentType: 'application/json; charset=utf-8',
        successSchemaId: 'UserDto',
        paramsSchemaId: 'UserPath',
        params: const UserPath(id: '42'),
        querySchemaId: 'UserQuery',
        query: const UserQuery(includeDeleted: true, tags: ['alpha', 'beta']),
        headersSchemaId: 'RequestHeaders',
        headers: const RequestHeaders(requestId: 'req_1'),
        requestContentType: 'application/json; charset=utf-8',
        bodySchemaId: 'CreateUserBody',
        body: const CreateUserBody(name: 'Ada'),
      );

      expect(response, const UserDto(id: '42', name: 'Ada'));
    });
  });
}

final class _TestClient extends DartEdgeGeneratedClientBase {
  const _TestClient({
    required super.baseUri,
    required super.transport,
    super.codecs,
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
}

final class UserQuery {
  const UserQuery({required this.includeDeleted, required this.tags});

  final bool includeDeleted;
  final List<String> tags;
}

final class RequestHeaders {
  const RequestHeaders({required this.requestId});

  final String requestId;
}

final class CreateUserBody {
  const CreateUserBody({required this.name});

  final String name;
}

final class UserDto {
  const UserDto({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) {
    return other is UserDto && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}
