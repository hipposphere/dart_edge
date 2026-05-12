# dart_edge_shelf

Shelf handler integration for Dart Edge HTTP servers.

```dart
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_shelf/dart_edge_shelf.dart';
import 'package:shelf/shelf.dart';

Future<void> main() async {
  final app = DartEdge<void>(services: () {});

  app.mountShelfHandler(
    (request) => Response.ok('Shelf saw ${request.url}'),
  );

  await app.listen(port: 8080);
}
```

The default mount path is `/<shelfPath*>`, which forwards `/`, nested app
routes, and static asset paths to the same Shelf handler.

Final wildcard route segments are intentionally only allowed at the end of a
route pattern. The captured wildcard value is available as a normal path
parameter, for example `ctx.req.param('shelfPath')`.
