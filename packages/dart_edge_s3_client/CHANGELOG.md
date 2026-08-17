## 0.3.18

- Add single-owner native-stream uploads that feed S3 directly without
  materializing the object body in Dart memory.
- Enforce the declared upload length and release or cancel the producer on
  success, validation failure, stream failure, or request failure.
- Bump the native artifact version to 0.1.14 for the streaming PUT ABI and
  Tokio-safe native producer composition.

## 0.3.17

- Add closed, open-ended, and suffix byte ranges to in-memory, Dart-streamed,
  and native-streamed S3 downloads.
- Preserve selected response length, total object length, and `Content-Range`
  metadata without routing native stream bytes through Dart.
- Bump the native artifact version to 0.1.12 for the ranged GET ABI.

## 0.3.16

- Add a dual-use native object stream that can expose Dart chunks or transfer
  directly into a compatible native consumer.
- Retain AWS-owned stream chunks through native HTTP delivery instead of
  copying each chunk into an intermediate Rust allocation.
- Bump the native artifact version to 0.1.11 for zero-copy native chunks.

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
