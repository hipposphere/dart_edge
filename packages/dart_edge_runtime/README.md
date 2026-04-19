# dart_edge_runtime

Core runtime and shared contract package for Dart Edge.

Use this package directly when you want the low-level Dart Edge API surface
without the umbrella import. It owns the route contracts, request context,
schema registry model, middleware configuration, and native server bridge.

## Quick Start

```dart
import 'package:dart_edge_runtime/dart_edge_runtime.dart';

Future<void> main() async {
  final app = DartEdge<AppServices>(services: AppServices.new);

  app.get('/health', handler: (ctx) => const {'status': 'ok'});
  await app.listen(host: '0.0.0.0', port: 8080);
}

final class AppServices {
  const AppServices();
}
```

For local-only development, omit `host:` and the runtime stays bound to
`127.0.0.1`. For deployment, pass a real bind address such as `0.0.0.0` or
`::`.

## Key Building Blocks

- `DartEdge` starts the native server and dispatches requests to registered
  routes
- `Router.get`, `post`, `put`, `patch`, `delete`, `head`, and `options` add
  inline HTTP handlers without writing a route class, with metadata grouped in
  `RouteOptions`
- `JsonRouteDefinition` is the main HTTP route base class
- `RouteContract`, `RequestBody`, `ResponseSpec`, and `ResponseSet` describe the
  request and response shape
- `RequestContext` gives handlers access to services, decoded request values, and
  request-scoped extensions
- `JsonSchemaRef`, `JsonSchemaDefinition`, and `JsonSchemaRegistry` connect the
  runtime to generated JSON Schema metadata
- `RustMiddleware` configures the transport-layer middleware stack

See [example/native_probe.dart](example/native_probe.dart) for the native asset
probe and [../dart_edge/example/simple_http_server.dart](../dart_edge/example/simple_http_server.dart)
for a larger application example that uses this runtime surface.

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_runtime.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_runtime run ffigen --config tool/ffigen.yaml
```
