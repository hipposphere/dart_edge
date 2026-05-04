# dart_edge_native_assets

Shared build hook helpers for Dart Edge native asset packages.

This package is consumed by Dart Edge package `hook/build.dart` files. It first
tries to use prebuilt Linux and macOS release binaries keyed by the Rust crate
version from `rust/Cargo.toml`, then falls back to a local Rust build for
unsupported platforms, architectures, or missing artifacts.
