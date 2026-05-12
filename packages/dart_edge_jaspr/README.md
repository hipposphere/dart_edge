# dart_edge_jaspr

Jaspr app mounting and HTML rendering helpers for Dart Edge.

This package keeps the runtime boundary clean:

- `dart_edge_core` still owns request and route contracts
- `dart_edge_shelf` owns the Shelf handler adapter
- `dart_edge_jaspr` mounts Jaspr's `serveApp(...)` handler through Shelf
- higher-level page and email components belong in `dart_edge_jaspr_helpers`

## Current API

- `JasprRenderer.renderString(...)` renders a Jaspr component tree to HTML
- `Router.mountJasprApp(...)` mounts a full Jaspr app through Jaspr's
  `serveApp(...)` handler via `dart_edge_shelf`

## Example

```dart
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_jaspr/dart_edge_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/server.dart';

Future<void> main() async {
  final app = DartEdge<void>(services: () {});

  app.mountJasprApp(
    Document(
      title: 'Welcome',
      base: null,
      body: div([
        Component.text('Hello from Jaspr and Dart Edge'),
      ]),
    ),
    catchAllPath: '/<jasprPath*>',
    paths: const [],
  );

  await app.listen(port: 8080);
}
```

```dart
app.mountJasprApp(
  docs,
  catchAllPath: '/<jasprPath*>',
  paths: const [],
);
```

Static files are handled by Jaspr's `serveApp(...)` handler, so configure them
the same way you would in a normal Jaspr app.

The catch-all path requires a runtime native artifact that supports final
wildcard route segments.

`dart_edge_jaspr` auto-initializes Jaspr with default server options before
rendering or mounting. If you need generated Jaspr server options for `@client`
components or other advanced server features, initialize Jaspr yourself first.
