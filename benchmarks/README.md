# Benchmarks

This directory contains benchmark suites. Each suite owns its own targets,
runner, docs, and optional recorded results under `benchmarks/<suite>/`.

## Current Suites

- [`basic-http-server`](basic-http-server/README.md): small equivalent HTTP
  servers that exercise the same plaintext, JSON, path-parameter, and echo
  scenarios across Dart Edge, Shelf Router, Node.js, and Rust baselines.

## Workspace Layout

- Dart benchmark packages live under `benchmarks/<suite>/<target>/`.
- Shared suite docs live under `benchmarks/<suite>/README.md`.
- Cross-language targets can keep their normal toolchain files in the same
  suite directory.

Keep each suite focused on one comparison problem so adding a new benchmark does
not force unrelated targets or methodology into the same runner.
