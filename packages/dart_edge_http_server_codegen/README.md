# dart_edge_http_server_codegen

Build-time JSON Schema and generator-facing APIs for Dart Edge HTTP.

This package provides a `build_runner` builder for schema-inferred Dart model
types plus lower-level generator APIs for tooling that already has normalized
HTTP route metadata.

## Core Concepts

- `FromSchema` generates a Dart model class from a const `JsonSchema`
- `JsonSchemaRegistry` references can be supplied to validate `$ref` usage
- `DartEdgeHttpServerGenerator` emits server artifacts from normalized route
  specs
- `DartEdgeClientGenerator` emits Dart client classes from normalized route
  metadata
- `DartEdgeGeneratedClientBase` and the client transport types provide the
  runtime support surface for generated clients

## Schema Model Generation

Add this package and `build_runner` to an app package:

```yaml
dev_dependencies:
  build_runner: ^2.14.1
  dart_edge_http_server_codegen: ^0.3.1
```

Define const schemas and type aliases:

```dart
import 'package:dart_edge_http_server_codegen/dart_edge_http_server_codegen.dart';
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

part 'users.g.dart';

const createUserInputSchema = JsonSchema.object(
  id: 'CreateUserInput',
  properties: <String, JsonSchema>{
    'name': JsonSchema.string(),
    'email': JsonSchema.string(format: 'email'),
  },
  required: <String>['name', 'email'],
  additionalProperties: false,
);

const userSchemas = JsonSchemaRegistry(
  schemas: <JsonSchema>[createUserInputSchema],
);

@FromSchema(createUserInputSchema, registry: userSchemas)
typedef CreateUserInput = _$CreateUserInput;
```

Run generation:

```sh
dart run dart_edge_http_server_codegen:build
```

The generated part emits the private backing class used by the public typedef:

```dart
final class _$CreateUserInput {
  const _$CreateUserInput({required this.name, required this.email});

  static const schemaRef =
      JsonSchemaRef<CreateUserInput>('CreateUserInput');

  final String name;
  final String email;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'email': email,
  };

  static CreateUserInput fromJson(Object? value) {
    // ...
  }
}
```

## Server Artifact Generation

`DartEdgeHttpServerGenerator` is intentionally built around normalized specs.
Custom tooling can construct these specs directly.

```dart
final source = const DartEdgeHttpServerGenerator().generate(
  DartEdgeHttpServerLibrarySpec(
    clientClassName: 'UsersClient',
    schemas: userSchemas.schemas,
    routes: [
      DartEdgeHttpRouteSpec(
        routeClassName: 'CreateUserRoute',
        method: HttpMethod.post,
        path: '/users',
        options: createUserRouteOptions,
        successType: 'UserDto',
        bodyType: 'CreateUserInput',
      ),
    ],
  ),
);
```

## Client Generation

`dart_edge_http_server_codegen` also contains the client-generation slice for
HTTP routes. It is intentionally built around normalized route options and
schema ids, not runtime reflection.
