# dart_edge_benchmark_shelf_router

Shelf Router benchmark target used for Dart Edge comparisons.

This package is an executable benchmark target, not a reusable library. It
serves the shared benchmark scenarios with `package:shelf_router`.

Run it directly with:

```sh
dart pub -C benchmarks/basic-http-server/shelf_router run bin/server.dart --port=8080
```

For the full benchmark workflow, see [../README.md](../README.md).
