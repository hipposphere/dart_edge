# Basic HTTP Server Results

Date: 2026-04-19

Source data: [`runner/latest.json`](runner/latest.json)

Command:

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart \
  --targets=dart_edge,shelf_router,express,fastify,fastapi,axum \
  --scenarios=all \
  --warmup=1 \
  --duration=2 \
  --concurrency=32 \
  --base-port=9880 \
  --json-out=benchmarks/basic-http-server/runner/latest.json
```

## Target Map

| Target | Language / runtime | Based on |
| --- | --- | --- |
| `dart_edge` | Dart AOT | `DartEdge.listen()` integrated server path |
| `shelf_router` | Dart AOT | `package:shelf_router` |
| `express` | Node.js | `express` |
| `fastify` | Node.js | `fastify` |
| `fastapi` | Python | `FastAPI`, served by `uvicorn` |
| `axum` | Rust | `axum` |

## Headline Comparison

- `axum` leads every scenario at `42.7k-43.9k rps`, with the lowest p50 latency (`0.72-0.74 ms`) and the smallest memory footprint (`4.2-4.5 MB` peak RSS).
- `fastify` is slightly ahead of `dart_edge` on average throughput in this run (`34.3k` vs `33.8k` avg RPS, `+1.3%`), driven by wins on `json` and `path_param`.
- `dart_edge` still wins the write-heavy `echo` case over `fastify` by `14.6%` while staying at `18.3-20.4 MB` peak RSS instead of Fastify's `76.1-224.1 MB`.
- `express` remains the middle-of-the-pack baseline: clearly ahead of `shelf_router` and `fastapi`, but still behind `dart_edge`, `fastify`, and `axum` in every scenario.
- `shelf_router` narrowly edges `fastapi` on average throughput in this rerun (`+1.4%`) and does it with materially lower memory use.

## Average Across Scenarios

| Target | Language/runtime | Avg RPS | Avg p50 ms | Peak RSS MB |
| --- | --- | ---: | ---: | ---: |
| Axum | Rust | 43,228.2 | 0.73 | 4.5 |
| Fastify | Node.js | 34,279.2 | 0.83 | 224.1 |
| Dart Edge | Dart AOT | 33,835.3 | 0.91 | 20.4 |
| Express | Node.js | 27,527.3 | 1.07 | 85.7 |
| Shelf Router | Dart AOT | 17,077.6 | 1.85 | 20.2 |
| FastAPI | Python | 16,844.5 | 2.02 | 52.1 |

## Plaintext

| Target | RPS | p50 ms | Peak RSS MB |
| --- | ---: | ---: | ---: |
| Axum | 42,674.9 | 0.74 | 4.2 |
| Dart Edge | 36,008.9 | 0.85 | 20.4 |
| Fastify | 31,388.0 | 0.80 | 86.6 |
| Express | 29,575.5 | 1.00 | 80.4 |
| FastAPI | 19,481.4 | 1.75 | 52.1 |
| Shelf Router | 18,059.2 | 1.75 | 19.4 |

## JSON

| Target | RPS | p50 ms | Peak RSS MB |
| --- | ---: | ---: | ---: |
| Axum | 43,581.6 | 0.72 | 4.3 |
| Fastify | 38,385.7 | 0.77 | 76.1 |
| Dart Edge | 33,350.3 | 0.93 | 18.3 |
| Express | 27,846.9 | 1.03 | 83.8 |
| FastAPI | 17,953.5 | 1.85 | 35.1 |
| Shelf Router | 17,289.0 | 1.81 | 19.5 |

## Path Parameter

| Target | RPS | p50 ms | Peak RSS MB |
| --- | ---: | ---: | ---: |
| Axum | 43,855.6 | 0.72 | 4.4 |
| Fastify | 38,522.6 | 0.77 | 76.2 |
| Dart Edge | 32,940.6 | 0.92 | 18.4 |
| Express | 27,983.9 | 1.05 | 78.6 |
| Shelf Router | 17,064.3 | 1.86 | 20.1 |
| FastAPI | 15,834.5 | 2.19 | 35.7 |

## Echo

| Target | RPS | p50 ms | Peak RSS MB |
| --- | ---: | ---: | ---: |
| Axum | 42,800.7 | 0.74 | 4.5 |
| Dart Edge | 33,041.6 | 0.94 | 18.5 |
| Fastify | 28,820.5 | 0.97 | 224.1 |
| Express | 24,702.9 | 1.19 | 85.7 |
| Shelf Router | 15,898.0 | 2.00 | 20.2 |
| FastAPI | 14,108.5 | 2.29 | 36.2 |

## Notes

- CPU is process CPU across all logical cores, so `100%` is roughly one fully used logical core.
- All default Dart targets in this table were built with `dart build cli` before launch.
- The FastAPI target was served by `uvicorn`, using the local `fastapi/.venv`.
- `axum` was built in Rust release mode.
- Results are machine-local. Compare targets from the same run, not across different machines or background-load conditions.
