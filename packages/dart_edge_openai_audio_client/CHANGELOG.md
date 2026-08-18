## 0.1.2

- Allow transcription requests to omit the multipart `model` field for
  provider endpoints that select their model implicitly.

## 0.1.1

- Add cancellable byte and native-stream transcription operation handles.
- Propagate cancellation into active native upload producers and bound response
  waiting with the configured request timeout.
- Add an integration test covering native transport lease ownership, pooled
  PCM finishing, native WAV streaming, and provider multipart upload.
- Bump the native artifact ABI to version 2.

## 0.1.0

- Add native-backed OpenAI-compatible file transcription.
- Accept Dart-owned bytes or a single-owner `NativeByteStreamHandle`.
- Stream native audio into multipart encoding without materializing it in the
  Dart heap.
- Support custom OpenAI-compatible base URLs, headers, and multipart fields.
