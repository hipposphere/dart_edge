## 0.3.15

- Add idempotent explicit close support for download streams.
- Cancel all owned streams when a client is disposed and expose native stream
  lifecycle counters.
- Bump the native artifact version to 0.1.9 for the lifecycle counter ABI.

## 0.3.14

- Add a backpressured `getObjectStream` API that reads one native S3 body
  chunk at a time without materializing the complete object.
- Bump the native artifact version to 0.1.8 for the streaming download ABI.

## 0.3.9

- Bump the native artifact version to 0.1.3 for Rust 1.95 and dependency
  updates.

## 0.3.7

- Bump the native artifact version to 0.1.2 for rebuilt prebuilts.
- Require `dart_edge_native_assets` 0.1.2.

## 0.3.5

- Publish Linux arm64 native artifacts.

## 0.3.4

- Use prebuilt Linux and macOS native assets when available, with Rust source
  build fallback.

## 0.3.0

- Declare internal Dart Edge dependencies with the internal hosted registry.

## 0.2.0

- Update package constraints for the native HTTP routing and shared core API changes.

## 0.1.0

- Initial internal release.
