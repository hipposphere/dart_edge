# dart_edge_benchmark_runner

Benchmark runner for the Dart Edge benchmark workspace.

The runner starts each target, validates the scenarios, warms them up with
`oha`, measures throughput and latency, samples CPU/RSS, and can emit a JSON
report.

## Quick Start

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart
```

Run a narrower slice:

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart \
  --targets=dart_edge,shelf_router,express,fastapi \
  --scenarios=plaintext,json \
  --warmup=2 \
  --duration=5 \
  --concurrency=64
```

Write a JSON report:

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart --json-out=latest.json
```

The shared methodology and prerequisites live in [../README.md](../README.md).
