# Auth DB HTTP Benchmark

- Generated: `2026-04-18T17:07:53.083364Z`
- Targets: `dart_edge_http_server`, `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- CPU cap: `single-core (~100% total CPU)`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. The runner also CPU-caps each server process to roughly one core. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary
- `sign_in`: Dart Edge wins on throughput; Dart Edge `58.5` ops/s vs Fastify `29.2` ops/s, p50 `524.51` ms vs `1087.83` ms, peak RSS `45.8` MB vs `270.3` MB, delta `100.0%` vs Fastify.
- `raw_authed`: Dart Edge wins on throughput; Dart Edge `532.4` ops/s vs Fastify `0.0` ops/s, p50 `7.62` ms vs `0.00` ms, peak RSS `46.0` MB vs `268.0` MB, delta `0.0%` vs Fastify.
- `db_authed`: Dart Edge wins on throughput; Dart Edge `1536.9` ops/s vs Fastify `0.0` ops/s, p50 `9.85` ms vs `0.00` ms, peak RSS `46.5` MB vs `258.2` MB, delta `0.0%` vs Fastify.
- `flow`: Dart Edge wins on throughput; Dart Edge `58.5` ops/s vs Fastify `26.6` ops/s, p50 `551.82` ms vs `1187.97` ms, peak RSS `45.9` MB vs `264.9` MB, delta `119.7%` vs Fastify.

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | dart_edge_http_server | 92 | 0 | 58.5 | 524.51 | 586.59 | 97.5 | 100.1 | 45.8 | 45.8
sign_in | fastify | 32 | 0 | 29.2 | 1087.83 | 1094.24 | 200.7 | 213.6 | 270.0 | 270.3
raw_authed | dart_edge_http_server | 536 | 0 | 532.4 | 7.62 | 745.57 | 73.4 | 88.2 | 46.0 | 46.0
raw_authed | fastify | 0 | 0 | 0.0 | 0.00 | 0.00 | 183.1 | 209.3 | 261.5 | 268.0
db_authed | dart_edge_http_server | 1553 | 0 | 1536.9 | 9.85 | 251.74 | 98.1 | 99.4 | 46.5 | 46.5
db_authed | fastify | 0 | 0 | 0.0 | 0.00 | 0.00 | 193.0 | 203.2 | 257.9 | 258.2
flow | dart_edge_http_server | 64 | 0 | 58.5 | 551.82 | 555.05 | 98.7 | 101.0 | 45.9 | 45.9
flow | fastify | 32 | 0 | 26.6 | 1187.97 | 1200.66 | 184.3 | 211.5 | 263.4 | 264.9
