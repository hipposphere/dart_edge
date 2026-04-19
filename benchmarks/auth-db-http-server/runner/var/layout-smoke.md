# Auth DB HTTP Benchmark

- Generated: `2026-04-18T16:42:56.203584Z`
- Targets: `dart_edge_http_server`, `fastify`
- Scenarios: `flow`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `flow`: Fastify wins because Dart Edge produced errors on throughput; Dart Edge `0.0` ops/s vs Fastify `13.9` ops/s, p50 `0.00` ms vs `71.51` ms, peak RSS `45.4` MB vs `168.1` MB, delta `-100.0%` vs Fastify. Reliability: Dart Edge `93` errors, Fastify `0` errors.

## Reliability

- `dart_edge_http_server` / `flow`: `93` errors during measurement. First error: `Bad state: GET http://127.0.0.1:9180/bench/raw returned 401.`.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
flow | dart_edge_http_server | 0 | 93 | 0.0 | 0.00 | 0.00 | 84.9 | 87.6 | 45.4 | 45.4
flow | fastify | 14 | 0 | 13.9 | 71.51 | 75.97 | 98.5 | 103.5 | 168.0 | 168.1
