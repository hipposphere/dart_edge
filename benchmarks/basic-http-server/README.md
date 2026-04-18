# Basic HTTP Server Benchmarks

This suite compares the real `DartEdge.listen()` HTTP server path against a
small set of equivalent HTTP servers that implement the same scenarios.

## Current Targets

- `dart_edge`: the integrated `DartEdge.listen()` server path, built with
  `dart build cli`
- `shelf_router`: `package:shelf_router` route matching, built with
  `dart build cli`
- `express`: `express` on Node.js
- `fastify`: `fastify` on Node.js
- `fastapi`: `FastAPI` on Python, served by `uvicorn`
- `axum`: `axum` on Rust

Optional JIT-only targets remain available for diagnostics:

- `dart_edge_jit`
- `shelf_router_jit`

## Scenarios

- `plaintext`: `GET /plaintext`
- `json`: `GET /json`
- `path_param`: `GET /users/42`
- `echo`: `POST /echo`

Each target must serve the same paths, return the same status codes, and return
the same response bodies for those scenarios.

## Running

Resolve the workspace first:

```sh
dart pub get
```

Install the external benchmark tooling once:

```sh
cargo install oha --locked
cd benchmarks/basic-http-server/express && npm install
cd ../fastify && npm install
cd ../fastapi && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

Run the full suite:

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart
```

That default run uses the default non-JIT comparison set and excludes JIT-only
diagnostic targets unless you name them explicitly.

Run a narrower slice:

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart \
  --targets=dart_edge,shelf_router,express,fastapi,axum \
  --scenarios=plaintext,json \
  --warmup=2 \
  --duration=5 \
  --concurrency=64
```

Optionally write machine-readable output:

```sh
dart run benchmarks/basic-http-server/runner/bin/run.dart \
  --json-out=latest.json
```

## Methodology

- One target runs at a time on the same machine.
- `oha` drives the load for every target and emits latency/RPS summaries in
  JSON.
- Every scenario is validated with a single request before warmup so a target
  cannot "win" by returning the wrong payload.
- Every scenario is warmed up before measurement.
- CPU and RSS are sampled from the server process with `ps` during the
  measurement window and reported as average and peak values.
- CPU is process CPU across all logical cores. On macOS and Linux, `100%`
  means roughly one fully used core, so `300%` means the process averaged about
  three cores during the measurement window.
- The Rust `axum` target is built in `--release` before launch.
- All default Dart targets are built with `dart build cli` before launch.
- The FastAPI target is started with `uvicorn` and the runner prefers
  `benchmarks/basic-http-server/fastapi/.venv` when it exists.
- JIT-only targets are opt-in and should only be used when comparing runtime
  behavior, not production-style throughput or memory.
- Results are machine-local. Compare targets from the same run, not across
  different machines or background-load conditions.

The latest recorded human-readable summary, if present, lives in
[`RESULTS.md`](RESULTS.md). The raw machine-readable data lives in
[`runner/latest.json`](runner/latest.json).
