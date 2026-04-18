# Auth DB HTTP Benchmark

- Generated: `2026-04-18T16:54:20.800871Z`
- Targets: `dart_edge`, `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `sign_in`: Dart Edge wins on throughput; Dart Edge `63.6` ops/s vs Fastify `63.2` ops/s, p50 `496.20` ms vs `501.41` ms, peak RSS `46.2` MB vs `286.6` MB, delta `0.6%` vs Fastify.
- `raw_authed`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `0.0` ops/s vs Fastify `1270.4` ops/s, p50 `0.00` ms vs `22.43` ms, peak RSS `46.3` MB vs `362.4` MB, delta `-100.0%` vs Fastify. Reliability: Dart Edge `320` errors, Fastify `0` errors.
- `db_authed`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `0.0` ops/s vs Fastify `1271.3` ops/s, p50 `0.00` ms vs `21.90` ms, peak RSS `46.3` MB vs `351.8` MB, delta `-100.0%` vs Fastify. Reliability: Dart Edge `320` errors, Fastify `0` errors.
- `flow`: Dart Edge wins on throughput; Dart Edge `59.6` ops/s vs Fastify `57.9` ops/s, p50 `533.78` ms vs `551.47` ms, peak RSS `46.6` MB vs `375.3` MB, delta `2.9%` vs Fastify.

## Reliability

- `dart_edge` / `raw_authed`: `320` errors during measurement. First error: `Bad state: GET http://127.0.0.1:9180/bench/raw returned 401.`.
- `dart_edge` / `db_authed`: `320` errors during measurement. First error: `Bad state: GET http://127.0.0.1:9180/bench/db returned 401.`.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | dart_edge | 350 | 0 | 63.6 | 496.20 | 522.60 | 99.6 | 102.4 | 46.1 | 46.2
sign_in | fastify | 320 | 0 | 63.2 | 501.41 | 540.69 | 401.2 | 410.4 | 280.8 | 286.6
raw_authed | dart_edge | 0 | 320 | 0.0 | 0.00 | 0.00 | 98.8 | 100.9 | 46.2 | 46.3
raw_authed | fastify | 6384 | 0 | 1270.4 | 22.43 | 30.04 | 171.0 | 360.6 | 359.0 | 362.4
db_authed | dart_edge | 0 | 320 | 0.0 | 0.00 | 0.00 | 99.2 | 101.2 | 46.2 | 46.3
db_authed | fastify | 6381 | 0 | 1271.3 | 21.90 | 37.75 | 168.6 | 356.4 | 347.8 | 351.8
flow | dart_edge | 320 | 0 | 59.6 | 533.78 | 558.74 | 99.5 | 101.6 | 46.5 | 46.6
flow | fastify | 320 | 0 | 57.9 | 551.47 | 563.59 | 378.8 | 399.3 | 349.3 | 375.3
