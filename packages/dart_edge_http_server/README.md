# dart_edge_http_server

App-facing HTTP server package for building Dart Edge services.

Import `package:dart_edge_http_server/dart_edge_http_server.dart` when you want the normal developer
experience: the runtime contracts from `dart_edge_http_server_runtime` plus
app-facing helpers in one import.

## What You Get

- `DartEdge` and `Router` for starting the server and registering routes with
  `get`/`post`/`put`/`patch`/`delete` helpers, plus `routeGet`/`routePost`
  helpers for explicit route classes
- `RouteOptions` for inline handlers and `RouteContract` for explicit route
  definitions
- `OpenApiHelpers` for mounting helper endpoints alongside your app
- WebSocket handlers with text, JSON, binary, and mixed-frame streams
- `JasprRenderer` and `getJaspr` / `postJaspr` style helpers for HTML routes
- `dart_edge_jaspr_helpers` components for reusable Jaspr-backed page and email
  scaffolds

## Quick Start

```dart
import 'package:dart_edge_http_server/dart_edge_http_server.dart';

Future<void> main() async {
  final app = DartEdge<AppServices>(
    services: AppServices.new,
    openApiDocument: OpenApiDocument(
      title: 'Example API',
      version: '1.0.0',
    ),
  );

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

## Request Bodies

Use `ctx.req` for decoded bodies, native body access, and multipart parsing:

```dart
app.post('/upload', handler: (ctx) async {
  final rawBody = ctx.req.nativeBody;
  final copied = rawBody?.copyBytes();

  final form = await ctx.req.multipart();
  final file = form.files.single;
  return {'bodyBytes': copied?.length ?? file.length};
});
```

`nativeBody` is a borrowed native view for the current request. Copy it before
storing it beyond the handler.

## WebSocket Routes

Use `messages.json<T>()` for JSON text protocols and `messages.binary()` or
`messages.frames()` when the route needs raw binary data:

```dart
app.websocket('/audio', onConnect: (socket) async {
  await socket.sendJson({'ready': true});

  await for (final bytes in socket.messages.binary()) {
    await socket.sendBinary(bytes);
  }
});
```
