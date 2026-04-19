# Auth DB HTTP Server Results

Date: 2026-04-19

Source data: [`runner/latest.json`](runner/latest.json)

Command:

```sh
dart run benchmarks/auth-db-http-server/runner/bin/run.dart \
  --scenarios=all \
  --warmup=2 \
  --duration=5 \
  --concurrency=16 \
  --base-port=9980 \
  --json-out=benchmarks/auth-db-http-server/runner/latest.json
```

## Target Map

| Target | Language / runtime | Based on |
| --- | --- | --- |
| `dart_edge_http_server` | Dart AOT | `DartEdge.listen()` with `dart_edge_auth` and native `dart_edge_s3_client` |
| `fastify` | Node.js | `fastify` with Better Auth, `@fastify/multipart`, and `@aws-sdk/client-s3` |

## Workload

- `sign_in`: Better Auth email/password sign-in against the seeded benchmark user pool.
- `raw_authed`: authenticated JSON route with no database read in the handler.
- `db_authed`: authenticated JSON route plus a SQLite lookup in the handler.
- `upload_multipart`: authenticated `multipart/form-data` upload of a fixed 47,104-byte file, stored to a runner-managed mock S3-compatible endpoint from inside the handler.
- `flow`: sequential sign-in, authenticated raw request, and authenticated DB-backed request over rotating pre-seeded users.

## Headline Comparison

- `dart_edge_http_server` wins every scenario in this rerun.
- Throughput deltas vs `fastify`: `+116.8%` on `sign_in`, `+185.9%` on `raw_authed`, `+183.7%` on `db_authed`, `+299.4%` on `upload_multipart`, and `+169.6%` on `flow`.
- `dart_edge_http_server` stays in a `49.0-90.0 MB` peak RSS band across the full five-scenario suite, while `fastify` ranges from `331.0 MB` to `497.9 MB`.
- The multipart-to-S3 path adds visible memory pressure on both targets, but Dart Edge still holds roughly a `4.0x` throughput advantage and uses about `19.6%` of Fastify's peak RSS on that scenario.

## Average Across Scenarios

| Target | Language/runtime | Avg ops/s | Avg p50 ms | Peak RSS MB |
| --- | --- | ---: | ---: | ---: |
| Dart Edge | Dart AOT | 1,812.7 | 110.68 | 90.0 |
| Fastify | Node.js | 603.1 | 267.32 | 497.9 |

## Sign In

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 56.5 | 272.87 | 54.0 | 0 |
| Fastify | 26.1 | 592.28 | 331.0 | 0 |

## Raw Authed

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 3,814.3 | 3.30 | 49.0 | 0 |
| Fastify | 1,334.3 | 8.07 | 497.9 | 0 |

## DB Authed

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 3,406.3 | 4.23 | 49.9 | 0 |
| Fastify | 1,200.8 | 9.13 | 493.4 | 0 |

## Upload Multipart

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 1,727.2 | 5.43 | 90.0 | 0 |
| Fastify | 432.5 | 22.58 | 459.3 | 0 |

## Flow

| Target | Ops/s | p50 ms | Peak RSS MB | Errors |
| --- | ---: | ---: | ---: | ---: |
| Dart Edge | 59.0 | 267.58 | 54.2 | 0 |
| Fastify | 21.9 | 704.56 | 340.0 | 0 |

## Notes

- This run used the default single-core runner mode plus the suite's in-process mock S3 server, so both targets hit the same local S3-compatible endpoint without external network variance.
- Process CPU is capped only approximately; sampled CPU can still read above `100%`, especially on the multipart/S3 path where extra native or worker threads stay active during the measured window.
- One fresh server is started per target/scenario pair, warmed before measurement, then sampled for CPU and RSS during the measured window.
- Authenticated follow-up requests use the Better Auth bearer token returned by the sign-in step.
- Results are machine-local. Compare targets from the same run, not across different machines or background-load conditions.
