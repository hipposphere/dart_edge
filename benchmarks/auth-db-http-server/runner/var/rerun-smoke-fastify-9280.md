# Auth DB HTTP Benchmark

- Generated: `2026-04-19T09:13:31.188835Z`
- Targets: `fastify`
- Scenarios: `sign_in`, `raw_authed`, `db_authed`, `flow`
- CPU cap: `single-core (~100% total CPU)`
- Workload: Better Auth email/password sign-in, an authenticated raw endpoint, an authenticated SQLite read, and a full sequential flow.
- Methodology: one fresh server per target/scenario pair, warmed before measurement, with CPU and RSS sampled from the server process during the measured window. The runner also CPU-caps each server process to roughly one core. Authenticated follow-up requests use the Better Auth session token as a bearer token, and the flow scenario rotates through a pre-seeded user pool to avoid same-user reuse artifacts.

## Summary

## Results

Scenario | Target | Ops | Errors | Ops/s | P50 ms | P99 ms | CPU avg % | CPU max % | RSS avg MB | RSS max MB
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
sign_in | fastify | 24 | 0 | 22.9 | 94.65 | 103.80 | 126.0 | 140.5 | 204.9 | 210.3
raw_authed | fastify | 605 | 0 | 601.1 | 2.42 | 16.31 | 104.6 | 119.7 | 218.4 | 254.5
db_authed | fastify | 612 | 0 | 607.8 | 2.44 | 18.40 | 106.9 | 118.4 | 217.8 | 262.7
flow | fastify | 22 | 0 | 21.0 | 99.36 | 105.87 | 127.0 | 142.7 | 200.7 | 206.6
