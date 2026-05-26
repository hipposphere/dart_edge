## 0.3.7

- Add a native audio worker pool for in-memory probe and conversion jobs.
- Route `DartEdgeAudio.initialize()` through the native pool so warmed bytes
- Remove the legacy Dart worker path so audio APIs use the native pool.
- Bump the native artifact version to 0.1.5 for the native pool ABI.

## 0.3.6

- Add `DartEdgeAudio.initialize()` for warming audio probing/conversion before
  latency-sensitive requests.

## 0.3.4

- Bump the native artifact version to 0.1.3 for Rust 1.95 and dependency
  updates.

## 0.3.3

- Bump the native artifact version to 0.1.2 for rebuilt prebuilts.
- Require `dart_edge_native_assets` 0.1.2.

## 0.3.2

- Publish Linux arm64 native artifacts.

## 0.3.1

- Use prebuilt Linux and macOS native assets when available, with Rust source
  build fallback.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
