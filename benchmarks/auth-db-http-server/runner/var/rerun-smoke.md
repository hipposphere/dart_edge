# Auth DB HTTP Benchmark

- Generated: `2026-04-19T09:28:51.877680Z`
- Targets: `dart_edge_http_server`, `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- CPU cap: `single-core (~100% total CPU)`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. The runner also CPU-caps each server process to roughly one core. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `sign_in`: Dart Edge wins on throughput; Dart Edge `64.7` ops/s vs Fastify `21.9` ops/s, p50 `30.79` ms vs `95.78` ms, peak RSS `44.5` MB vs `201.5` MB, delta `194.9%` vs Fastify.
- `raw_authed`: Dart Edge wins on throughput; Dart Edge `2518.0` ops/s vs Fastify `685.8` ops/s, p50 `0.70` ms vs `2.04` ms, peak RSS `45.0` MB vs `286.8` MB, delta `267.2%` vs Fastify.
- `db_authed`: Dart Edge wins on throughput; Dart Edge `3001.0` ops/s vs Fastify `697.4` ops/s, p50 `0.58` ms vs `2.03` ms, peak RSS `45.0` MB vs `286.5` MB, delta `330.3%` vs Fastify.
- `flow`: Dart Edge wins on throughput; Dart Edge `54.2` ops/s vs Fastify `20.4` ops/s, p50 `35.90` ms vs `102.12` ms, peak RSS `44.6` MB vs `211.5` MB, delta `165.1%` vs Fastify.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | dart_edge_http_server | 66 | 0 | 64.7 | 30.79 | 34.13 | 80.5 | 98.7 | 44.5 | 44.5
sign_in | fastify | 24 | 0 | 21.9 | 95.78 | 107.02 | 128.0 | 139.3 | 196.0 | 201.5
raw_authed | dart_edge_http_server | 2519 | 0 | 2518.0 | 0.70 | 4.39 | 58.0 | 64.2 | 44.9 | 45.0
raw_authed | fastify | 687 | 0 | 685.8 | 2.04 | 20.83 | 105.0 | 121.4 | 237.5 | 286.8
db_authed | dart_edge_http_server | 3022 | 0 | 3001.0 | 0.58 | 1.52 | 85.3 | 99.2 | 44.9 | 45.0
db_authed | fastify | 702 | 0 | 697.4 | 2.03 | 20.77 | 103.9 | 124.0 | 238.9 | 286.5
flow | dart_edge_http_server | 56 | 0 | 54.2 | 35.90 | 58.35 | 86.6 | 91.1 | 44.6 | 44.6
flow | fastify | 22 | 0 | 20.4 | 102.12 | 148.17 | 129.1 | 148.3 | 205.9 | 211.5
