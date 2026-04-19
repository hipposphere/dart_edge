# dart_edge_jaspr

Jaspr-based HTML rendering and route helpers for Dart Edge.

This package keeps the runtime boundary clean:

- `dart_edge_core` still owns request and route contracts
- `dart_edge_jaspr` turns Jaspr components into `text/html` responses
- higher-level page and email components belong in `dart_edge_jaspr_helpers`

## Current API

- `JasprRenderer.renderString(...)` renders a Jaspr component tree to HTML
- `JasprRenderer.html(...)` returns a `RawResponse` for direct route use
- `JasprRenderer.document(...)` builds and renders a Jaspr `Document`
- `Router.getJaspr` / `postJaspr` / `putJaspr` / `patchJaspr` / `deleteJaspr`
  / `headJaspr` / `optionsJaspr` register HTML routes with `ResponseSpec.html()`

## Example

```dart
import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

Future<void> main() async {
  final app = DartEdge<void>(services: () {});

  app.getJaspr(
    '/welcome',
    handler: (_) => Document(
      title: 'Welcome',
      base: null,
      body: div([
        Component.text('Hello from Jaspr and Dart Edge'),
      ]),
    ),
  );

  await app.listen(port: 8080);
}
```

`dart_edge_jaspr` auto-initializes Jaspr with default server options on first
render. If you need generated Jaspr server options for `@client` components or
other advanced server features, initialize Jaspr yourself before the first
render.
