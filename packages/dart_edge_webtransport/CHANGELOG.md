## 0.1.5

- Add long-lived unidirectional and bidirectional stream handles on native and
  browser clients.
- Deliver native stream operations and datagrams through nonblocking readiness
  events instead of a blocking isolate call per chunk.
- Expose incoming native stream chunks as single-owner payload leases and bound
  native receive queues to preserve transport backpressure.
- Preserve `sendStream` and `streams` as whole-payload compatibility helpers.
- Generate the native FFI surface from the package C header and bump the native
  ABI and artifact version.

## 0.1.1

- Add native WebTransport reliable stream payload support.
- Add generated-client transport adapter support for datagrams and streams.
- Require `dart_edge_core` 0.3.11.
- Bump the native artifact version to 0.1.2 for Rust 1.95 and dependency
  updates.

## 0.1.0

- Initial internal release with browser and native WebTransport client support.
