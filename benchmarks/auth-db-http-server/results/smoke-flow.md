# Auth DB HTTP Benchmark

- Generated: `2026-04-18T15:16:31.018060Z`
- Targets: `dart_edge`, `fastify`
- Scenarios: `flow`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `flow`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `47.5` ops/s vs Fastify `27.3` ops/s, p50 `35.95` ms vs `73.03` ms, peak RSS `44.8` MB vs `210.3` MB, delta `74.1%` vs Fastify. Reliability: Dart Edge `8` errors, Fastify `0` errors.

## Reliability

- `dart_edge` / `flow`: `8` errors during measurement. First error: `Bad state: Flow GET http://127.0.0.1:9180/bench/db returned 401.`.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
flow | dart_edge | 48 | 8 | 47.5 | 35.95 | 41.01 | 68.1 | 91.4 | 44.8 | 44.8
flow | fastify | 28 | 0 | 27.3 | 73.03 | 79.54 | 146.3 | 183.2 | 202.9 | 210.3
