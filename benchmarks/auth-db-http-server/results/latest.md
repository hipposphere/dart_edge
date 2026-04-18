# Auth DB HTTP Benchmark

- Generated: `2026-04-18T15:14:07.434511Z`
- Targets: `dart_edge`, `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `sign_in`: Dart Edge wins because Fastify produced errors on throughput; Dart Edge `32571.9` ops/s vs Fastify `858.8` ops/s, p50 `0.48` ms vs `239.21` ms, peak RSS `45.6` MB vs `267.8` MB, delta `3692.6%` vs Fastify. Reliability: Dart Edge `0` errors, Fastify `4216` errors.
- `raw_authed`: Dart Edge wins because Fastify produced errors on throughput; Dart Edge `36377.5` ops/s vs Fastify `1805.7` ops/s, p50 `0.42` ms vs `10.01` ms, peak RSS `45.5` MB vs `271.5` MB, delta `1914.6%` vs Fastify. Reliability: Dart Edge `0` errors, Fastify `7456` errors.
- `db_authed`: Dart Edge wins on throughput; Dart Edge `36579.0` ops/s vs Fastify `1567.3` ops/s, p50 `0.43` ms vs `9.84` ms, peak RSS `45.5` MB vs `270.5` MB, delta `2233.9%` vs Fastify.
- `flow`: Fastify wins on throughput; Dart Edge `0.0` ops/s vs Fastify `12.4` ops/s, p50 `0.00` ms vs `289.21` ms, peak RSS `45.9` MB vs `327.3` MB, delta `-100.0%` vs Fastify. Reliability: Dart Edge `19909` errors, Fastify `264` errors.

## Reliability

- `dart_edge` / `flow`: `19909` errors during measurement. First error: `Bad state: Flow sign_in returned 429.`.
- `fastify` / `sign_in`: `4216` errors during measurement. First error: `Can't assign requested address (os error 49)`.
- `fastify` / `raw_authed`: `7456` errors during measurement. First error: `Can't assign requested address (os error 49)`.
- `fastify` / `flow`: `264` errors during measurement. First error: `Bad state: Flow sign_in returned 401.`.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | dart_edge | 162925 | 0 | 32571.9 | 0.48 | 0.75 | 144.7 | 152.4 | 45.6 | 45.6
sign_in | fastify | 190 | 4216 | 858.8 | 239.21 | 470.61 | 248.1 | 420.7 | 262.1 | 267.8
raw_authed | dart_edge | 181988 | 0 | 36377.5 | 0.42 | 0.71 | 140.4 | 148.7 | 45.5 | 45.5
raw_authed | fastify | 1616 | 7456 | 1805.7 | 10.01 | 42.78 | 40.7 | 151.1 | 261.1 | 271.5
db_authed | dart_edge | 183029 | 0 | 36579.0 | 0.43 | 0.67 | 141.6 | 147.0 | 45.5 | 45.5
db_authed | fastify | 7844 | 0 | 1567.3 | 9.84 | 18.45 | 142.1 | 179.0 | 269.5 | 270.5
flow | dart_edge | 0 | 19909 | 0.0 | 0.00 | 0.00 | 41.4 | 58.5 | 45.5 | 45.9
flow | fastify | 64 | 264 | 12.4 | 289.21 | 691.74 | 397.4 | 415.1 | 324.0 | 327.3
