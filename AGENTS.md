# Dart Edge Agent Guide

This repository is a Dart monorepo organized as a Pub workspace rooted at the
repository root and composed from `packages/*`, with shared Rust crates under
`crates/*`.

## Repo Shape

- `CONCEPT.md`: evolving product and architecture concept
- `packages/dart_edge_http_server`: umbrella package that application authors should import
- `packages/dart_edge_http_server_runtime`: concrete runtime package and shared contract
  surface
- `packages/dart_edge_http_server_runtime/hook`: SDK-discovered build hooks for the runtime
- `packages/dart_edge_http_server_runtime/rust`: Rust crate compiled into the runtime's
  native asset
- `crates/dart_edge_core`: shared Rust FFI primitives used by native packages
- `crates/dart_edge_sql_core`: shared Rust SQL wire payload types used by native packages
- `benchmarks`: reproducible benchmark apps and the benchmark runner
- `packages/dart_edge_http_server_codegen`: build-time HTTP generation and generator-facing API
- `packages/dart_edge_s3_client`: standalone native S3 client package for AWS
  S3 and compatible object stores
- `packages/dart_edge_sip`: standalone native SIP runtime concept package for
  backend-controlled VoIP and PBX-style call handling
- `.agents/skills`: repo-local skills for recurring monorepo, runtime, and
  codegen work

## Dart Baseline

- Target Dart `>=3.11.0 <4.0.0`.
- Treat Dart 3.11 as the minimum language baseline for repo design and API
  examples.
- Use Pub workspaces instead of older monorepo tools for dependency resolution.
- Keep all first-party packages under `packages/` so `workspace: ['packages/*']`
  picks them up automatically.
- Benchmark apps can live under `benchmarks/` and should also be included in the
  root workspace.
- Every workspace package must use `resolution: workspace`.

## Commands

- Resolve the whole workspace: `dart pub get`
- List workspace packages: `dart pub workspace list`
- Analyze the whole repo: `dart analyze`
- Format the whole repo: `dart format .`
- Test one package: `cd packages/<package> && dart test`
- Work on one package with pub commands: `dart pub -C packages/<package> <cmd>`
- Exercise the runtime native asset: `cd packages/dart_edge_http_server_runtime && dart run example/native_probe.dart`
- Run the benchmark suite: `dart pub -C benchmarks/basic-http-server/runner run bin/run.dart`
- Check shared Rust crates: `cargo check --workspace`
- Check one native asset crate: `cargo check --manifest-path packages/<package>/rust/Cargo.toml`

## Package Rules

- Do not add a new package outside `packages/`.
- Exception: benchmark packages belong under `benchmarks/`, not `packages/`.
- Do not add stray `pubspec.yaml` files between the repo root and a workspace
  package.
- Keep helper-only APIs out of `dart_edge_http_server_runtime`.
- Keep package-owned native asset crates inside `packages/<package>/rust`.
- Keep reusable Rust libraries under `crates/` and make published native asset
  crates depend on them through normal Cargo version dependencies, not sibling
  `path` dependencies.
- Codegen packages must stay pure Dart unless a later design explicitly changes
  that.
- Keep app-facing schema annotation contracts in `dart_edge_core`.
- Keep generated API surface in `dart_edge_http_server_codegen`.
- Keep app-facing imports simple by exporting the normal runtime and helper
  surface from `dart_edge_http_server`.
- Keep benchmark targets small and symmetrical. If one target adds a route or
  payload shape for comparison, update the other benchmark targets to match.

## Examples

- Public package examples belong in `packages/<package>/example/`.
- Keep examples small, runnable, and end-to-end enough to show the intended
  package usage.
- Use `package:dart_edge_http_server/dart_edge_http_server.dart` for app-level examples unless the task
  is specifically demonstrating a lower-level package in isolation.
- When helper APIs such as OpenAPI/Swagger mounting are part of the happy path,
  show them in examples instead of only describing them in docs.

## Code Style

- Prefer package imports over relative imports across package boundaries.
- Keep Dart source files focused and reasonably small. If a file starts mixing
  contracts, runtime wiring, helpers, and annotations, split it into `lib/src/`
  by concern instead of growing one umbrella file.
- Prefer package-level entrypoints that mostly export smaller `src/` libraries.
- Group `lib/src/` by domain when it improves navigation, for example
  `contracts/`, `context/`, `routes/`, `runtime/`, or `native/`.
- Use UpperCamelCase for every class-like declaration:
  classes, mixins, enums, typedef-like public wrappers, and annotation classes.
- Do not introduce lowercase annotation classes such as `@path` or `@query`;
  use `@Path()`, `@Query()`, and other UpperCamelCase names instead.
- Prefer modern Dart features when they improve clarity and reduce repetition:
  dot shorthands, pattern matching, records, destructuring, exhaustive switches,
  and the newer class modifiers.
- Use dot shorthands where the context type is already obvious, especially for
  enum values, named constructors, and concise static-member access.
- Use records and patterns for small multi-value flows and destructuring, not as
  a substitute for stable public contract types.
- Use `sealed`, `final`, `base`, and `interface` deliberately to express API
  boundaries, but do not over-constrain extension points that application code
  is expected to implement.
- Keep public contracts explicit. Route shape should live in one contract object
  rather than being spread across many unrelated fields.
- Build Dart code generators with `code_builder` instead of handwritten source
  string assembly. Keep raw `Code` snippets small and localized to expression or
  statement bodies that `code_builder` cannot model clearly.
- Avoid experimental language features unless the repo explicitly opts into
  them.

## Architecture Guardrails

- Runtime and shared contract types live together in `dart_edge_http_server_runtime`.
- App-facing helpers can wrap or mount runtime capabilities from
  `dart_edge_http_server`, but they should not redefine core contracts.
- Generated code should compile down to normalized route contracts and JSON
  Schema references rather than relying on runtime type inspection.
- JSON Schema support must preserve `$ref` support for shared and recursive
  models.

## Native Packages

- Use Dart build hooks in `hook/`, singular, following the current Dart package
  layout conventions.
- Hook dependencies such as `hooks`, `code_assets`, and
  `native_toolchain_rust` must live under normal `dependencies`, not
  `dev_dependencies`, because consuming apps execute those hooks.
- Build native libraries with `native_toolchain_rust`; do not add ad hoc shell
  scripts or platform-specific build glue when the hook can own the build.
- Use the repo-root Cargo workspace for shared Rust crates. Package-owned
  native asset crates are intentionally excluded from that workspace because
  independent native assets can have incompatible native `links` dependencies.
- The root `.cargo/config.toml` maps shared crates in `crates/` to local paths
  during repo development while package manifests keep normal Cargo version
  dependencies for publication.
- Do not put `path = "../../..."` dependencies in package native asset crates
  that will be published to Pub; consumers only receive the package root, not
  monorepo sibling directories.
- Do not check in `packages/<package>/rust/Cargo.lock` for published native
  asset crates; local Cargo patches would otherwise leak into package archives.
- Keep the generated native asset ID aligned with the Dart library URI that
  declares the generated bindings.
- For `dart_edge_http_server_runtime`, the asset name should stay `dart_edge_http_server_runtime.dart`.
- For `dart_edge_auth`, the asset name should stay `dart_edge_auth.dart`.
- For `dart_edge_sip`, the asset name should stay `dart_edge_sip.dart`.
- Keep the exported C ABI intentionally small and stable.
- Treat each package's `rust/include/*.h` file as the Dart FFI source header.
- Generate Dart FFI bindings with `ffigen`; do not hand-edit
  `lib/src/native/generated_bindings.dart`.
- Current commands:
  `dart pub -C packages/dart_edge_core run ffigen --config tool/ffigen.yaml`
  and
  `dart pub -C packages/dart_edge_http_server_runtime run ffigen --config tool/ffigen.yaml`
  and
  `dart pub -C packages/dart_edge_auth run ffigen --config tool/ffigen.yaml`
  and
  `dart pub -C packages/dart_edge_s3_client run ffigen --config tool/ffigen.yaml`
  and
  `dart pub -C packages/dart_edge_sip run ffigen --config tool/ffigen.yaml`.
- If a Rust-exported symbol or native struct layout changes, update the header,
  regenerate the bindings, and update a verification test or example in the
  same change.
- Pin the Rust toolchain in `rust/rust-toolchain.toml` and grow the supported
  target list deliberately when the runtime's platform support expands.

## Testing Expectations

- Run `dart analyze` after structural or API changes.
- Add or update tests in the package you changed when behavior changes.
- If codegen is introduced or modified, validate both the source annotations and
  the generated output shape.

## Benchmarks

- Keep the benchmark methodology explicit in `benchmarks/README.md`.
- Compare equivalent endpoints only: same method, path shape, payload size, and
  status code across all targets.
- Use the real `benchmarks/basic-http-server/dart_edge_http_server` target for Dart Edge
  comparisons. Do not add fake adapters or benchmark-only shims that bypass the
  normal runtime API.
- Cross-language benchmark targets belong in `benchmarks/<suite>/<target>/` and
  should be runnable directly with the runtime's normal toolchain (`dart`,
  `node`, `cargo`, etc.).
- Prefer a real external HTTP benchmark tool for comparative runs. The current
  repo runner is built around `oha`, with per-scenario response validation and
  server-process CPU/RSS sampling during measurement.

## Skills

Use the repo-local skills in `.agents/skills` when the task is clearly about:

- workspace/package layout
- runtime contracts and API boundaries
- JSON Schema and codegen design
