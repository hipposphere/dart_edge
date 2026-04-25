# Dart Edge Rust Crates

This directory contains reusable Rust crates that are shared by Dart Edge
native asset packages.

Package-owned native asset crates stay under `packages/<package>/rust`. Shared
Rust libraries live here so published Dart packages can depend on them through
normal Cargo version dependencies instead of monorepo-relative `path`
dependencies.

## Crates

- `dart_edge_core`: C-compatible FFI primitives shared by native packages.
- `dart_edge_sql_core`: JSON wire contracts shared by SQL native bridges.

## Local Development

The repo root has a Cargo workspace for the crates in this directory. It also
has `.cargo/config.toml` patch entries that point Cargo dependencies such as
`dart_edge_core = "0.1.0"` back to these local crates while working in the
monorepo.

Native asset crates under `packages/<package>/rust` are intentionally excluded
from the root Cargo workspace. They are independent build products and can have
native `links` dependencies that conflict if Cargo resolves every native asset
crate in one workspace graph.

Useful commands:

```sh
cargo test --workspace
RUSTDOCFLAGS='-D warnings' cargo doc --workspace --no-deps
cargo package --manifest-path crates/dart_edge_core/Cargo.toml --allow-dirty
cargo package --manifest-path crates/dart_edge_sql_core/Cargo.toml --allow-dirty
```

Check a package-owned native asset crate with:

```sh
cargo check --manifest-path packages/<package>/rust/Cargo.toml
```

## Publishing

Publish shared crates before publishing Dart packages that depend on them.

Recommended order:

1. `dart_edge_core`
2. `dart_edge_sql_core`
3. Dart packages with native asset crates that depend on those Cargo crates

Package native asset manifests should use version dependencies, for example:

```toml
dart_edge_core = "0.1.0"
dart_edge_sql_core = "0.1.0"
```

Do not use sibling `path = "../../..."` dependencies in package native asset
crates intended for Pub publication. A Pub consumer receives the package root,
not the original monorepo sibling directories.

Do not check in `packages/<package>/rust/Cargo.lock` for published native asset
crates. Local Cargo patches would otherwise leak into package archives.
