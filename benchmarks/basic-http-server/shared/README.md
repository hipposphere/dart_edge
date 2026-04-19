# dart_edge_benchmark_shared

Shared scenarios, payloads, and helper functions for the benchmark workspace.

Import this package from benchmark targets or the runner when you need the
canonical scenario list, expected payloads, or small CLI helpers such as port
parsing.

## What It Provides

- `BenchmarkScenario` and its derived request/response metadata
- shared plaintext and JSON payload fixtures for the benchmark scenarios
- utility helpers such as `parseBenchmarkPort()`,
  `encodeBenchmarkJson()`, and `benchmarkUserPayload()`
