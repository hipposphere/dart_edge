# Auth DB HTTP Benchmark

- Generated: `2026-04-18T15:19:14.003795Z`
- Targets: `dart_edge`, `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `sign_in`: Dart Edge wins on throughput; Dart Edge `59.5` ops/s vs Fastify `30.2` ops/s, p50 `33.15` ms vs `66.03` ms, peak RSS `44.7` MB vs `202.7` MB, delta `97.2%` vs Fastify.
- `raw_authed`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `197.6` ops/s vs Fastify `725.3` ops/s, p50 `1.12` ms vs `2.38` ms, peak RSS `44.1` MB vs `263.8` MB, delta `-72.8%` vs Fastify. Reliability: Dart Edge `51` errors, Fastify `0` errors.
- `db_authed`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `197.3` ops/s vs Fastify `643.6` ops/s, p50 `1.00` ms vs `2.56` ms, peak RSS `44.8` MB vs `296.5` MB, delta `-69.3%` vs Fastify. Reliability: Dart Edge `53` errors, Fastify `0` errors.
- `flow`: Dart Edge wins on throughput; Dart Edge `53.2` ops/s vs Fastify `27.5` ops/s, p50 `36.17` ms vs `72.19` ms, peak RSS `44.9` MB vs `215.3` MB, delta `93.4%` vs Fastify.

## Reliability

- `dart_edge` / `raw_authed`: `51` errors during measurement. First error: `Bad state: GET http://127.0.0.1:9180/bench/raw returned 401.`.
- `dart_edge` / `db_authed`: `53` errors during measurement. First error: `Bad state: GET http://127.0.0.1:9180/bench/db returned 401.`.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | dart_edge | 61 | 0 | 59.5 | 33.15 | 37.84 | 82.3 | 99.3 | 44.2 | 44.7
sign_in | fastify | 32 | 0 | 30.2 | 66.03 | 68.87 | 159.8 | 192.5 | 195.9 | 202.7
raw_authed | dart_edge | 199 | 51 | 197.6 | 1.12 | 2.14 | 79.1 | 93.1 | 44.0 | 44.1
raw_authed | fastify | 729 | 0 | 725.3 | 2.38 | 5.84 | 109.7 | 127.1 | 226.0 | 263.8
db_authed | dart_edge | 199 | 53 | 197.3 | 1.00 | 1.77 | 79.1 | 92.3 | 44.8 | 44.8
db_authed | fastify | 649 | 0 | 643.6 | 2.56 | 7.32 | 114.5 | 128.7 | 248.5 | 296.5
flow | dart_edge | 54 | 0 | 53.2 | 36.17 | 77.27 | 78.6 | 91.9 | 44.9 | 44.9
flow | fastify | 28 | 0 | 27.5 | 72.19 | 78.93 | 153.0 | 191.0 | 206.9 | 215.3
