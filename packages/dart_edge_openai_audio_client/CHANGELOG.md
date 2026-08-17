## 0.1.0

- Add native-backed OpenAI-compatible file transcription.
- Accept Dart-owned bytes or a single-owner `NativeByteStreamHandle`.
- Stream native audio into multipart encoding without materializing it in the
  Dart heap.
- Support custom OpenAI-compatible base URLs, headers, and multipart fields.
