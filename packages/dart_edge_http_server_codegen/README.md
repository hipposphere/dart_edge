# dart_edge_http_server_codegen

Build-time annotations and generator-facing APIs for Dart Edge HTTP server
generation.

This package provides a `build_runner` builder plus the lower-level generator
APIs behind it. The builder reads annotated Dart libraries and emits
`*.g.dart` part files containing `RouteOptions` objects, JSON Schema
registries, runtime codec registry factories, generated route wrappers, and
optional typed clients.

## Core Concepts

- `TypedJsonRoute` declares HTTP metadata for a generated JSON route
- `PathParam`, `QueryParam`, and `HeaderParam` describe how parameters bind
- `RouteBody`, `SuccessResponse`, and `RouteErrorResponse` describe payload and
  response metadata
- `DartEdgeHttpServerGenerator` emits normalized server artifacts from
  annotation-derived route specs
- `DartEdgeClientGenerator` emits Dart client classes from normalized route
  metadata
- `DartEdgeGeneratedClientBase` and the client transport/codec types provide
  the runtime support surface for generated clients

## build_runner Usage

Add this package and `build_runner` to an app package:

```yaml
dev_dependencies:
  build_runner: ^2.14.1
  dart_edge_http_server_codegen: ^0.2.0
```

Annotate top-level route functions and include the generated part:

```dart
import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

part 'users.g.dart';

@TypedJsonRoute(
  method: HttpMethod.post,
  path: '/users/<id>',
  operationId: 'createUser',
  summary: 'Create a user.',
)
Future<UserDto> createUser(
  @PathParam('id') String id,
  @RouteBody() CreateUserInput body,
  @HeaderParam('x-request-id') String? requestId,
) async {
  return UserDto(id: id, name: body.name, email: body.email);
}
```

Run generation:

```sh
dart run dart_edge_http_server_codegen:build
```

The command is a thin wrapper around `build_runner`, so normal build_runner
flags still work:

```sh
dart run dart_edge_http_server_codegen:build --delete-conflicting-outputs
dart run dart_edge_http_server_codegen:build watch
```

The generated part exposes:

- `$generatedSchemas`
- `$generatedCodecs(...)`
- `$generatedRoutes<TServices>(...)`
- route options constants such as `createUserRouteOptions`

If a client should be emitted from the same route graph, configure the builder:

```yaml
targets:
  $default:
    builders:
      dart_edge_http_server_codegen:dart_edge_http_server:
        options:
          client_class_name: UsersClient
```

The current builder supports top-level `@TypedJsonRoute` functions, body
schemas from class fields, success schemas from return types, and object
schemas for annotated path/query/header parameters. App code still supplies the
actual runtime codecs because serialization is application-specific.

## Server Artifact Generation

`DartEdgeHttpServerGenerator` is intentionally built around normalized specs.
The `build_runner` builder creates these specs from annotations, while tests and
custom tooling can construct them directly.

```dart
final source = const DartEdgeHttpServerGenerator().generate(
  DartEdgeHttpServerLibrarySpec(
    clientClassName: 'UsersClient',
    schemas: userSchemas,
    routes: [
      DartEdgeHttpRouteSpec(
        routeClassName: 'CreateUserRoute',
        method: HttpMethod.post,
        path: '/users/<id>',
        contract: createUserRouteOptions,
        successType: 'UserDto',
        bodyType: 'CreateUserInput',
      ),
    ],
  ),
);
```

The emitted library includes:

- `RouteOptions` objects
- generated `HttpRouteDefinition` wrappers
- a generated function that mounts those wrappers on a `Router`
- a `JsonSchemaRegistry` with stable ids
- an optional generated client class

## Client Generation

`dart_edge_http_server_codegen` also contains the client-generation slice for HTTP
routes. It is intentionally built around normalized route options plus
schema-id keyed codecs, not runtime reflection.

```dart
final source = const DartEdgeClientGenerator().generate(
  DartEdgeClientLibrarySpec(
    className: 'UsersClient',
    operations: [
      DartEdgeClientOperation(
        method: HttpMethod.post,
        path: '/users/<id>',
        contract: userRouteOptions,
        successType: 'UserDto',
        paramsType: 'UserPath',
        queryType: 'GetUserQuery',
      ),
    ],
  ),
);
```

The generated client class extends `DartEdgeGeneratedClientBase` and uses:

- `DartEdgeClientTransport` for outbound HTTP
- `DartEdgeCodecRegistry` for schema-backed request/response conversion
- `RouteOptions` metadata for method, path, content type, and status handling
