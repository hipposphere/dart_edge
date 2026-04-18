# Basic HTTP Server Results

Date: 2026-04-18

Source data: [`runner/latest.json`](runner/latest.json)

Command:

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart \
  --targets=dart_edge,shelf_router,express,fastify,fastapi,axum \
  --scenarios=all \
  --warmup=1 \
  --duration=2 \
  --concurrency=32 \
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

- `axum` leads every scenario at `43.5k-46.2k rps`, with the lowest p50 latency (`0.68-0.71 ms`) and the smallest memory footprint (`4.2-4.5 MB` peak RSS).
- `dart_edge` is still the strongest overall balance after `axum`: `33.9k-37.5k rps`, `0.83-0.91 ms` p50, and `18.4-20.5 MB` peak RSS.
- `fastify` is close to `dart_edge` on `json` and `path_param`, and it wins `plaintext` by `8.6%`, but it falls to `78%` of `dart_edge` throughput on `echo` and peaks at `238.0 MB` RSS there.
- `express` now clearly outruns both `fastapi` and `shelf_router` in every scenario in this run, landing at `25.6k-29.3k rps`, but it does that with `80.7-92.9 MB` peak RSS.
- `fastapi` lands slightly ahead of `shelf_router` overall at `1.08x` average throughput, but it trails `express` in every scenario by `28.9-40.9%` while using about `1.6x-1.8x` less memory.

## Average Across Scenarios

Leader-normalized chart: longer bars mean higher throughput. `100%` is the best average RPS in this run.

| Target | Language/runtime | Avg RPS | vs leader | vs Dart Edge | Avg p50 ms | Peak RSS MB | Chart |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Axum | Rust | 45,422 | 100% | 126% | 0.69 | 4.5 | `########################` |
| Dart Edge | Dart AOT | 36,109 | 79% | 100% | 0.86 | 20.5 | `###################` |
| Fastify | Node.js | 34,538 | 76% | 96% | 0.84 | 238.0 | `##################` |
| Express | Node.js | 28,146 | 62% | 78% | 1.04 | 92.9 | `###############` |
| FastAPI | Python | 18,681 | 41% | 52% | 1.84 | 51.9 | `##########` |
| Shelf Router | Dart AOT | 17,268 | 38% | 48% | 1.84 | 19.3 | `#########` |

## Plaintext

`fastify` takes the read-only lead over `dart_edge` by `8.6%`, while `fastapi` is `10.2%` ahead of `shelf_router` but still `31.5%` behind `express`.

| Target | Language/runtime | RPS | vs winner | vs Dart Edge | p50 ms | Peak RSS MB | Chart |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Axum | Rust | 45,939 | 100% | 135% | 0.68 | 4.2 | `########################` |
| Fastify | Node.js | 37,103 | 81% | 109% | 0.78 | 92.8 | `###################` |
| Dart Edge | Dart AOT | 33,914 | 74% | 100% | 0.91 | 20.5 | `##################` |
| Express | Node.js | 29,068 | 63% | 86% | 1.01 | 80.7 | `###############` |
| FastAPI | Python | 19,925 | 43% | 59% | 1.77 | 51.8 | `##########` |
| Shelf Router | Dart AOT | 18,084 | 39% | 53% | 1.76 | 19.1 | `#########` |

## JSON

`dart_edge` retakes second place here, edging `fastify` by `1.1%`. `fastapi` stays ahead of `shelf_router` by `11.5%`, but it remains `32.9%` behind `express`.

| Target | Language/runtime | RPS | vs winner | vs Dart Edge | p50 ms | Peak RSS MB | Chart |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Axum | Rust | 46,247 | 100% | 124% | 0.68 | 4.3 | `########################` |
| Dart Edge | Dart AOT | 37,197 | 80% | 100% | 0.83 | 18.4 | `###################` |
| Fastify | Node.js | 36,776 | 80% | 99% | 0.78 | 92.9 | `###################` |
| Express | Node.js | 29,322 | 63% | 79% | 1.00 | 89.0 | `###############` |
| FastAPI | Python | 19,672 | 43% | 53% | 1.78 | 51.8 | `##########` |
| Shelf Router | Dart AOT | 17,639 | 38% | 47% | 1.79 | 19.3 | `#########` |

## Path Parameter

`dart_edge` stays ahead of `fastify` by `3.5%`. `fastapi` drops just below `shelf_router` here, trailing it by `2.5%`.

| Target | Language/runtime | RPS | vs winner | vs Dart Edge | p50 ms | Peak RSS MB | Chart |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Axum | Rust | 45,994 | 100% | 123% | 0.69 | 4.4 | `########################` |
| Dart Edge | Dart AOT | 37,461 | 81% | 100% | 0.83 | 18.4 | `####################` |
| Fastify | Node.js | 36,177 | 79% | 97% | 0.80 | 92.9 | `###################` |
| Express | Node.js | 28,556 | 62% | 76% | 1.02 | 90.4 | `###############` |
| Shelf Router | Dart AOT | 17,317 | 38% | 46% | 1.83 | 17.5 | `#########` |
| FastAPI | Python | 16,884 | 37% | 45% | 2.00 | 51.9 | `#########` |

## Echo

Body handling widens the gap again. `dart_edge` is `27.6%` faster than `fastify` here, and `fastify` pays for it with a `238.0 MB` peak RSS spike. `fastapi` is `13.8%` ahead of `shelf_router` but `28.9%` behind `express`.

| Target | Language/runtime | RPS | vs winner | vs Dart Edge | p50 ms | Peak RSS MB | Chart |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Axum | Rust | 43,510 | 100% | 121% | 0.71 | 4.5 | `########################` |
| Dart Edge | Dart AOT | 35,863 | 82% | 100% | 0.87 | 18.4 | `####################` |
| Fastify | Node.js | 28,096 | 65% | 78% | 1.00 | 238.0 | `###############` |
| Express | Node.js | 25,640 | 59% | 71% | 1.14 | 92.9 | `##############` |
| FastAPI | Python | 18,243 | 42% | 51% | 1.83 | 51.9 | `##########` |
| Shelf Router | Dart AOT | 16,033 | 37% | 45% | 1.98 | 17.8 | `#########` |

## Notes

- CPU is process CPU across all logical cores, so `100%` is roughly one fully used logical core.
- All default Dart targets in this table were built with `dart build cli` before launch.
- The FastAPI target was served by `uvicorn`, using the local `fastapi/.venv`.
- `axum` was built in Rust release mode.
- Results are machine-local. Compare targets from the same run, not across different machines or background-load conditions.
