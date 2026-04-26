# dart_edge_http_server_runtime

Core runtime and shared contract package for Dart Edge.

Use this package directly when you want the low-level Dart Edge API surface
without the higher-level HTTP server package. It owns the route contracts, request context,
schema registry model, middleware configuration, and native server bridge.

## Quick Start

```dart
import 'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart';

Future<void> main() async {
  final app = DartEdge<AppServices>(
    services: AppServices.new,
    openApiDocument: OpenApiDocument(
      title: 'Example API',
      version: '1.0.0',
    ),
  );

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
- `JsonSchemaRef`, `JsonSchema`, and `JsonSchemaRegistry` connect the
  runtime to generated JSON Schema metadata
- `RustMiddleware` configures the transport-layer middleware stack

## Request Body Ergonomics

Handlers should use `ctx.req` for both decoded Dart payloads and native body
access:

```dart
app.post('/upload', handler: (ctx) async {
  final rawBody = ctx.req.nativeBody;
  final bytes = rawBody?.copyBytes();

  final form = await ctx.req.multipart();
  final file = form.files.single;
  return {'bytes': bytes?.length ?? file.length};
});
```

`nativeBody` is a borrowed view and is only valid while the current request is
being handled. Copy bytes if data needs to outlive the handler.

See [example/native_probe.dart](example/native_probe.dart) for the native asset
probe and [../dart_edge_http_server/example/simple_http_server.dart](../dart_edge_http_server/example/simple_http_server.dart)
for a larger application example that uses this runtime surface.

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_http_server_runtime.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_http_server_runtime run ffigen --config tool/ffigen.yaml
```
