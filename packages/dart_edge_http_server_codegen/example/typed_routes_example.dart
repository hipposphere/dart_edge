import 'dart:async';
import 'dart:convert';

import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

part 'typed_routes_example.g.dart';

@TypedJsonRoute(
  method: HttpMethod.post,
  path: '/users',
  operationId: 'createUser',
  summary: 'Create a user.',
  tags: <String>['users'],
)
@SuccessResponse(status: 201)
external Future<UserDto> createUser(
  @RouteBody() CreateUserInput body,
  @HeaderParam('x-request-id') String? requestId,
);

Future<void> main() async {
  final app = DartEdge<AppServices>(services: AppServices.new);
  app.installSchemaRegistry($generatedSchemas);
  $generatedRoutes<AppServices>(
    app,
    createUserRoute: (body, requestId) {
      return UserDto(id: 'user-1', name: body.name, email: body.email);
    },
  );

  final openApiJson = app.buildOpenApiDocumentJson();
  print(const JsonEncoder.withIndent('  ').convert(openApiJson));

  final client = UsersClient(
    baseUri: Uri.parse('https://api.example.test'),
    transport: const ExampleTransport(),
  );

  final created = await client.createUser(
    headers: const <String, Object?>{'x-request-id': 'req_1'},
    body: const CreateUserInput(name: 'Ada', email: 'ada@example.com'),
  );
  print(created.id);
}

final class AppServices {
  const AppServices();
}

final class CreateUserInput {
  const CreateUserInput({required this.name, required this.email});

  final String name;
  final String email;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'email': email,
  };

  static CreateUserInput fromJson(Object? value) {
    final json = value! as Map<String, Object?>;
    return CreateUserInput(
      name: json['name']! as String,
      email: json['email']! as String,
    );
  }
}

final class UserDto {
  const UserDto({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'email': email,
  };

  static UserDto fromJson(Object? value) {
    final json = value! as Map<String, Object?>;
    return UserDto(
      id: json['id']! as String,
      name: json['name']! as String,
      email: json['email']! as String,
    );
  }
}

final class ExampleTransport implements DartEdgeClientTransport {
  const ExampleTransport();

  @override
  Future<DartEdgeClientResponse> send(DartEdgeClientRequest request) async {
    return DartEdgeClientResponse(
      status: 201,
      contentType: 'application/json; charset=utf-8',
      body: jsonEncode(<String, Object?>{
        'id': 'user-1',
        'name': 'Ada',
        'email': 'ada@example.com',
      }),
    );
  }
}
