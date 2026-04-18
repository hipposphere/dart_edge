# Auth DB HTTP Benchmark

- Generated: `2026-04-18T16:22:32.537377Z`
- Targets: `dart_edge`
- Scenarios: `flow`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
flow | dart_edge | 58 | 0 | 56.1 | 34.98 | 40.72 | 70.5 | 92.9 | 44.9 | 45.3
