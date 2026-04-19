# dart_edge_codegen

Build-time annotations and metadata types for Dart Edge route generation.

This package does not run generation by itself. Instead, it defines the
annotation surface that a builder or generator can read and translate into
`RouteContract` objects, JSON Schema registries, OpenAPI documents, or other
generated code.

## Core Concepts

- `TypedJsonRoute` declares HTTP metadata for a generated JSON route
- `PathParam`, `QueryParam`, and `HeaderParam` describe how parameters bind
- `RouteBody`, `SuccessResponse`, and `RouteErrorResponse` describe payload and
  response metadata
- `DartEdgeClientGenerator` emits Dart client classes from normalized route
  metadata
- `DartEdgeGeneratedClientBase` and the client transport/codec types provide
  the runtime support surface for generated clients

## Example

```dart
import 'package:dart_edge_codegen/dart_edge_codegen.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

@TypedJsonRoute(
  method: HttpMethod.post,
  path: '/users',
  operationId: 'createUser',
  summary: 'Create a user.',
)
Future<UserDto> createUser(
  @RouteBody() CreateUserInput body,
  @HeaderParam('x-request-id') String? requestId,
);
```

A generator can read that metadata and emit a concrete `JsonRouteDefinition`,
`RouteContract`, and JSON Schema wiring for the route.

## Client Generation

`dart_edge_codegen` also contains the first client-generation slice for HTTP
routes. It is intentionally built around normalized route contracts plus
schema-id keyed codecs, not runtime reflection.

```dart
final source = const DartEdgeClientGenerator().generate(
  DartEdgeClientLibrarySpec(
    className: 'UsersClient',
    operations: [
      DartEdgeClientOperation(
        contract: userRouteContract,
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
- `DartEdgeClientCodecRegistry` for schema-backed request/response conversion
- `RouteContract` metadata for method, path, content type, and status handling
