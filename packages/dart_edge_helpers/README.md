# dart_edge_helpers

Optional helper APIs for Dart Edge.

The helper surface is where convenience features that wrap the runtime belong.
Right now that surface is centered on OpenAPI-related mounting helpers that can
be attached to a `DartEdge` app.

## Current API

- `OpenApiHelpers.mountJson` reserves a path for serving the OpenAPI document
- `OpenApiHelpers.mountSwaggerUi` reserves a path for a Swagger UI page backed
  by that document

## Example

```dart
import 'package:dart_edge/dart_edge.dart';

final app = DartEdge<AppServices>(services: AppServices.new);

OpenApiHelpers.mountJson(app, path: '/openapi.json');
OpenApiHelpers.mountSwaggerUi(
  app,
  path: '/docs',
  specPath: '/openapi.json',
);
```

This package is intentionally small. Core request/response contracts still live
in `dart_edge_runtime`, while helpers like these stay here.
