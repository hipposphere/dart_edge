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
