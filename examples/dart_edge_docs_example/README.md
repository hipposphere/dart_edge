# Dart Edge Docs Example

Runnable `dart_edge_docs` Jaspr app.

```shell
cd examples/dart_edge_docs_example
dart pub get
dart run web/main.dart
```

The example starts a `DartEdge` HTTP server and mounts the complete docs app
with `app.mountDartEdgeDocs(docs)`. Content is loaded from `content/` through
`DartEdgeDocsApp`; the stylesheet is served by Jaspr from `web/styles.css`.
