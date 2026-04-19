# dart_edge_benchmark_dart_edge_http_server

Benchmark target that exercises the real `DartEdge.listen()` server path.

This package is an executable benchmark target, not a reusable library. The
benchmark runner starts it to compare Dart Edge against the other servers in
`benchmarks/`.

Run it directly with:

```sh
dart pub -C benchmarks/basic-http-server/dart_edge_http_server run bin/server.dart --port=8080
```

For the full benchmark workflow, see [../README.md](../README.md).
