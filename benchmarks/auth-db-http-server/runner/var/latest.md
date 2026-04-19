# Auth DB HTTP Benchmark

- Generated: `2026-04-18T17:20:37.940114Z`
- Targets: `dart_edge`, `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- CPU cap: `single-core (~100% total CPU)`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. The runner also CPU-caps each server process to roughly one core. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `sign_in`: Dart Edge wins on throughput; Dart Edge `60.5` ops/s vs Fastify `29.6` ops/s, p50 `521.95` ms vs `1089.74` ms, peak RSS `45.9` MB vs `278.9` MB, delta `104.1%` vs Fastify.
- `raw_authed`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `0.0` ops/s vs Fastify `927.0` ops/s, p50 `0.00` ms vs `23.02` ms, peak RSS `46.3` MB vs `347.2` MB, delta `-100.0%` vs Fastify. Reliability: Dart Edge `320` errors, Fastify `0` errors.
- `db_authed`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `0.0` ops/s vs Fastify `851.1` ops/s, p50 `0.00` ms vs `24.55` ms, peak RSS `46.7` MB vs `348.8` MB, delta `-100.0%` vs Fastify. Reliability: Dart Edge `320` errors, Fastify `0` errors.
- `flow`: Dart Edge wins on throughput; Dart Edge `59.3` ops/s vs Fastify `26.9` ops/s, p50 `534.12` ms vs `1181.24` ms, peak RSS `46.7` MB vs `297.2` MB, delta `120.2%` vs Fastify.

## Reliability

- `dart_edge` / `raw_authed`: `320` errors during measurement. First error: `Bad state: GET http://127.0.0.1:9180/bench/raw returned 401.`.
- `dart_edge` / `db_authed`: `320` errors during measurement. First error: `Bad state: GET http://127.0.0.1:9180/bench/db returned 401.`.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | dart_edge | 334 | 0 | 60.5 | 521.95 | 554.60 | 98.8 | 100.4 | 45.8 | 45.9
sign_in | fastify | 160 | 0 | 29.6 | 1089.74 | 1093.57 | 197.5 | 223.6 | 276.5 | 278.9
raw_authed | dart_edge | 0 | 320 | 0.0 | 0.00 | 0.00 | 98.4 | 101.4 | 46.2 | 46.3
raw_authed | fastify | 4652 | 0 | 927.0 | 23.02 | 75.55 | 131.4 | 203.4 | 344.2 | 347.2
db_authed | dart_edge | 0 | 320 | 0.0 | 0.00 | 0.00 | 98.4 | 100.7 | 46.6 | 46.7
db_authed | fastify | 4272 | 0 | 851.1 | 24.55 | 70.63 | 130.4 | 209.0 | 344.5 | 348.8
flow | dart_edge | 320 | 0 | 59.3 | 534.12 | 567.98 | 99.1 | 101.4 | 46.6 | 46.7
flow | fastify | 160 | 0 | 26.9 | 1181.24 | 1241.46 | 186.7 | 210.9 | 272.9 | 297.2
