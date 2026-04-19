# Auth DB HTTP Server Results

Date: 2026-04-19

Source data: [`runner/latest.json`](runner/latest.json)

Command:

```sh
dart run benchmarks/auth-db-http-server/runner/bin/run.dart \
  --warmup=2 \
  --duration=5 \
  --concurrency=16 \
  --base-port=9980 \
  --json-out=benchmarks/auth-db-http-server/runner/latest.json
```

## Target Map

| Target | Language / runtime | Based on |
| --- | --- | --- |
| `dart_edge_http_server` | Dart AOT | `DartEdge.listen()` with `dart_edge_auth` |
| `fastify` | Node.js | `fastify` with Better Auth |

## Workload

- `sign_in`: Better Auth email/password sign-in against the seeded benchmark user pool.
- `raw_authed`: authenticated JSON route with no database read in the handler.
- `db_authed`: authenticated JSON route plus a SQLite lookup in the handler.
- `flow`: sequential sign-in, authenticated raw request, and authenticated DB-backed request over rotating pre-seeded users.

## Headline Comparison

- `dart_edge_http_server` wins every scenario in this rerun.
- Throughput deltas vs `fastify`: `+141.0%` on `sign_in`, `+274.3%` on `raw_authed`, `+195.6%` on `db_authed`, and `+149.8%` on `flow`.
- `dart_edge_http_server` stays in a narrow `43.4-45.7 MB` peak RSS band across the full suite, while `fastify` ranges from `329.6 MB` to `478.9 MB`.
- The single-core cap makes the CPU numbers comparable across targets and keeps the auth workload focused on per-core efficiency instead of unconstrained parallelism.

## Average Across Scenarios

| Target | Language/runtime | Avg ops/s | Avg p50 ms | Peak RSS MB |
| --- | --- | ---: | ---: | ---: |
| Dart Edge | Dart AOT | 2,345.3 | 128.38 | 45.7 |
| Fastify | Node.js | 702.3 | 307.08 | 478.9 |

## Sign In

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 64.3 | 248.33 | 45.3 | 0 |
| Fastify | 26.7 | 598.67 | 329.6 | 0 |

## Raw Authed

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 5,243.5 | 2.77 | 45.7 | 0 |
| Fastify | 1,400.8 | 7.44 | 475.7 | 0 |

## DB Authed

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 4,011.7 | 3.54 | 43.4 | 0 |
| Fastify | 1,357.1 | 7.78 | 478.9 | 0 |

## Flow

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 61.7 | 258.88 | 43.9 | 0 |
| Fastify | 24.7 | 614.42 | 340.3 | 0 |

## Notes

- This run used the default single-core runner mode, so process CPU stays capped at roughly one logical core per target.
- One fresh server is started per target/scenario pair, warmed before measurement, then sampled for CPU and RSS during the measured window.
- Authenticated follow-up requests use the Better Auth bearer token returned by the sign-in step.
- Results are machine-local. Compare targets from the same run, not across different machines or background-load conditions.
