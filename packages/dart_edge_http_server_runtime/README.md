# dart_edge_http_server_runtime

Concrete HTTP runtime package for Dart Edge.

Use this package directly when you want the low-level Dart Edge API surface
without the higher-level HTTP server package. It re-exports the shared
contracts from `dart_edge_core`, but owns the concrete native server bridge,
route compilation, middleware configuration, and runtime request dispatch.

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
- `HttpRouteDefinition` is the main HTTP route base class from `dart_edge_core`
- `RouteOptions`, `RequestBody`, `ResponseSpec`, and `ResponseSet` describe the
  request and response shape in `dart_edge_core`
- `RequestContext` gives handlers access to services, decoded request values, and
  request-scoped extensions through `dart_edge_core`
- `WebSocketContext` gives WebSocket handlers typed text, JSON, binary, and
  mixed-frame streams plus matching send helpers
- `JsonSchema`, including `JsonSchema.ref`, and `JsonSchemaRegistry` connect the
  runtime to generated JSON Schema metadata through `dart_edge_core`
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

## WebSocket Frames

WebSocket routes can handle JSON control messages, raw text, binary streams, or
mixed protocols:

```dart
app.websocket('/stream', onConnect: (socket) async {
  await socket.sendText('ready');

  await for (final frame in socket.messages.frames()) {
    switch (frame.kind) {
      case WebSocketMessageKind.text:
        await socket.sendJson({'echo': frame.text});
      case WebSocketMessageKind.binary:
        await socket.sendBinary(frame.bytes);
    }
  }
});
```

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
