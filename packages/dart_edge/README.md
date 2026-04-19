# dart_edge

App-facing umbrella package for building Dart Edge services.

Import `package:dart_edge/dart_edge.dart` when you want the normal developer
experience: the runtime contracts from `dart_edge_runtime` plus the helper
surface from `dart_edge_helpers` in one import.

## What You Get

- `DartEdge` and `Router` for starting the server and registering routes with
  `get`/`post`/`put`/`patch`/`delete` helpers or `register()`
- `RouteOptions` for inline handlers and `RouteContract` for explicit route
  definitions
- `OpenApiHelpers` for mounting helper endpoints alongside your app
- `JasprRenderer` and `getJaspr` / `postJaspr` style helpers for HTML routes
- `dart_edge_jaspr_helpers` components for reusable Jaspr-backed page and email
  scaffolds

## Quick Start

```dart
import 'package:dart_edge/dart_edge.dart';

Future<void> main() async {
  final app = DartEdge<AppServices>(services: AppServices.new);

  app.get('/health', handler: (ctx) => const {'status': 'ok'});
  OpenApiHelpers.mountJson(app, path: '/openapi.json');

  await app.listen(port: 8080);
}

final class AppServices {
  const AppServices();
}
```

See [example/simple_http_server.dart](example/simple_http_server.dart) for a
larger end-to-end example with nested routers, inline handlers, middleware, and
OpenAPI helper mounting.
