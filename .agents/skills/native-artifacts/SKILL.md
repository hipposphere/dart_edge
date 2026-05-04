---
name: native-artifacts
description: Use when changing Dart Edge Rust native asset packages, build hooks, native GitHub Actions, Cargo versions, or publishing workflows; especially to check whether Rust native artifacts need rebuilding and whether Cargo package versions were bumped correctly.
---

# Native Artifacts

Dart Edge native packages publish Dart package versions separately from native
binary versions.

## Rules

- Use `packages/<package>/rust/Cargo.toml` `package.version` as the native
  artifact version.
- Use Dart `pubspec.yaml` `version` for Pub package releases.
- Do not rebuild native artifacts for Dart-only package changes when the Rust
  crate version did not change.
- Bump the Rust crate version when native inputs change:
  - `packages/<package>/rust/**`
  - shared Rust crate source/build files under `crates/*/src/**` or
    `crates/*/build.rs` used by that package
  - `.cargo/config.toml`
  - native build flags, toolchains, vendored native sources, headers, or ABI
    definitions that affect the binary
- Keep release tags in the form `<package>-native-v<cargoVersion>`.
- Keep artifact names in the form
  `<package>-<cargoVersion>-<os>-<arch>-<library>`.

## Workflow

1. Inspect changed files.
2. If native inputs changed, run:

   ```bash
   .agents/skills/native-artifacts/scripts/check_native_versions.sh origin/main
   ```

3. If the script reports unchanged Cargo versions, bump the relevant
   `packages/<package>/rust/Cargo.toml` versions before publishing.
4. After bumping native versions, let `.github/workflows/native-assets.yml`
   build the missing release assets. The workflow skips target artifacts that
   already exist for the same Cargo version.

## Supported Prebuilt Targets

- `linux-x64`
- `linux-arm64`
- `macos-arm64`

Other targets intentionally fall back to local Rust source builds.

## Package Support Notes

- `dart_edge_bluetooth_server` needs `pkg-config` and `libdbus-1-dev` on Linux
  CI runners.
- CI must read `packages/<package>/rust/rust-toolchain.toml` and run Cargo via
  `rustup run <channel>`; `dart_edge_sql_pglite` currently requires Rust 1.92.
- `dart_edge_sip` requires installed PJSIP headers for compilation and shared
  PJSIP libraries at runtime; it never bundles or directly links PJSIP.
- For unlinked SIP prebuilts, projects can set
  `DART_EDGE_SIP_PJPROJECT_LIBRARIES` to a semicolon-separated list of shared
  PJSIP library paths when the platform loader cannot find them by name.
