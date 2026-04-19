# Benchmarks

This directory contains benchmark suites. Each suite owns its own targets,
runner, docs, and optional recorded results under `benchmarks/<suite>/`.

## Current Suites

- [`basic-http-server`](basic-http-server/README.md): small equivalent HTTP
  servers that exercise the same plaintext, JSON, path-parameter, and echo
  scenarios across Dart Edge, Shelf Router, Node.js, and Rust baselines.
- [`auth-db-http-server`](auth-db-http-server/RESULTS.md): authenticated HTTP
  scenarios that compare Better Auth sign-in plus protected raw and DB-backed
  routes between Dart Edge and Fastify.

## Workspace Layout

- Dart benchmark packages live under `benchmarks/<suite>/<target>/`.
- Shared suite docs live under `benchmarks/<suite>/README.md` and/or
  `benchmarks/<suite>/RESULTS.md`.
- Cross-language targets can keep their normal toolchain files in the same
  suite directory.

Keep each suite focused on one comparison problem so adding a new benchmark does
not force unrelated targets or methodology into the same runner.
