## 0.2.6

- Add synchronous borrowed native transport-lease APIs for zero-copy streaming
  PCM16 VAD.
- Document 16 kHz mono PCM16LE as the streaming VAD input contract.

## 0.2.1

- Reuse Silero VAD tensor input buffers and pass borrowed ONNX Runtime tensor
  views to reduce per-window allocation and copy overhead.

## 0.2.0

- Replace isolate-backed VAD APIs with `NativeVad`, which owns a native worker
  pool internally.
- Add `NativeVadModel` and `NativeVadOptions` as the app-facing model and
  tuning API.
- Rename streaming APIs to `NativeVadStreamingSession` and
  `NativeVadStreamResult`.
- Add `NativeVadPoolMetrics` through `NativeVad.metrics` for observing native
  worker pool throughput, queue pressure, and completion notification failures.
- Complete native jobs through reusable Dart native-port notifications instead
  of Dart-side polling.

## 0.1.3

- Move `SileroVadWorker` onto the shared `DartEdgeIsolateWorker` foundation.

## 0.1.2

- Add pooled native Silero ONNX sessions for concurrent VAD requests.
- Add `SileroVadWorker` for reusing a long-lived isolate across detections.
- Add `SileroVadStreamingSession` for chunked stateful VAD processing.
- Add `NativePcm16Buffer` and native-pointer detection paths to avoid Dart FFI
  wrapper copies when callers can provide native memory.
- Add explicit `initialize()` warmup APIs for paying native ONNX cold-start
  latency before real audio arrives.

## 0.1.0

- Add initial Silero VAD package API, segment post-processing, and PCM/WAV
  trimming helpers.
