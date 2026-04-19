# Auth DB HTTP Benchmark

- Generated: `2026-04-19T09:33:17.369686Z`
- Targets: `dart_edge`, `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- CPU cap: `single-core (~100% total CPU)`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. The runner also CPU-caps each server process to roughly one core. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `sign_in`: Dart Edge wins on throughput; Dart Edge `62.8` ops/s vs Fastify `28.2` ops/s, p50 `251.11` ms vs `526.35` ms, peak RSS `44.5` MB vs `271.5` MB, delta `123.2%` vs Fastify.
- `raw_authed`: Dart Edge wins on throughput; Dart Edge `5027.3` ops/s vs Fastify `1180.9` ops/s, p50 `2.86` ms vs `9.51` ms, peak RSS `43.8` MB vs `384.3` MB, delta `325.7%` vs Fastify.
- `db_authed`: Dart Edge wins on throughput; Dart Edge `3652.3` ops/s vs Fastify `1158.7` ops/s, p50 `3.83` ms vs `9.78` ms, peak RSS `43.7` MB vs `371.0` MB, delta `215.2%` vs Fastify.
- `flow`: Dart Edge wins on throughput; Dart Edge `59.9` ops/s vs Fastify `28.3` ops/s, p50 `264.58` ms vs `573.59` ms, peak RSS `45.6` MB vs `289.6` MB, delta `111.9%` vs Fastify.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | dart_edge | 330 | 0 | 62.8 | 251.11 | 273.76 | 98.7 | 100.7 | 43.9 | 44.5
sign_in | fastify | 148 | 0 | 28.2 | 526.35 | 991.27 | 193.4 | 208.3 | 267.2 | 271.5
raw_authed | dart_edge | 25176 | 0 | 5027.3 | 2.86 | 6.91 | 91.8 | 96.0 | 43.8 | 43.8
raw_authed | fastify | 5914 | 0 | 1180.9 | 9.51 | 43.28 | 126.8 | 201.8 | 378.2 | 384.3
db_authed | dart_edge | 18282 | 0 | 3652.3 | 3.83 | 8.30 | 91.9 | 96.0 | 43.7 | 43.7
db_authed | fastify | 5803 | 0 | 1158.7 | 9.78 | 41.31 | 128.7 | 196.1 | 367.1 | 371.0
flow | dart_edge | 304 | 0 | 59.9 | 264.58 | 284.04 | 99.3 | 102.1 | 44.5 | 45.6
flow | fastify | 152 | 0 | 28.3 | 573.59 | 854.69 | 193.7 | 217.8 | 282.6 | 289.6
