# dart_edge_openai_audio_client

Native-backed file transcription for OpenAI and compatible providers such as
vLLM. Dart owns configuration and application orchestration; Rust owns HTTP,
multipart encoding, response limits, and native audio consumption.

The initial release covers `/v1/audio/transcriptions`. Realtime transcription
will use a separate session/event API in a later release.

## Dart bytes

```dart
final client = await OpenAiAudioClient.open(
  OpenAiAudioClientConfig(apiKey: Platform.environment['OPENAI_API_KEY']),
);

try {
  final response = await client.transcribeBytes(
    bytes: await File('recording.wav').readAsBytes(),
    request: const OpenAiAudioTranscriptionRequest(
      model: 'gpt-transcribe',
      filename: 'recording.wav',
      contentType: 'audio/wav',
    ),
  );
  print(response.text);
} finally {
  client.dispose();
}
```

## Native audio stream

Use `transcribeNativeStream` when another Dart Edge native package produced a
`NativeByteStreamHandle`:

```dart
final response = await client.transcribeNativeStream(
  body: normalized.body,
  contentLength: normalized.contentLength,
  request: const OpenAiAudioTranscriptionRequest(
    model: 'gpt-transcribe',
    filename: 'recording.wav',
    contentType: 'audio/wav',
  ),
);
```

The call consumes the single-owner handle. Audio chunks stay outside the Dart
heap and are copied directly into the native multipart encoder. The native
client cancels and releases the producer on every success or failure path.

## Cancellation

Use a `start...` method when the caller can disconnect while provider work is
active:

```dart
final operation = client.startTranscribeNativeStream(
  body: normalized.body,
  contentLength: normalized.contentLength,
  request: request,
);

connection.onDone(operation.cancel);
final response = await operation.response;
```

`cancel()` is idempotent. Native-stream cancellation reaches the active
producer immediately; request and response I/O is additionally bounded by
`OpenAiAudioClientConfig.requestTimeout`. Cancellation completes the future
with `OpenAiAudioRequestCancelledException`.

## OpenAI-compatible providers

`baseUrl` may point to an origin or an existing `/v1` prefix. The client
normalizes both to `/v1/audio/transcriptions`:

```dart
const config = OpenAiAudioClientConfig(
  baseUrl: 'http://127.0.0.1:8000/v1',
  allowHttp: true,
);
```

Plain HTTP is rejected unless `allowHttp` is explicitly enabled. Use
`additionalFields` for provider-specific multipart fields such as
`vad_filter`, `chunking_strategy`, or repeated timestamp options.

For providers that select a model from the endpoint, set `omitModel: true` on
`OpenAiAudioTranscriptionRequest`. The client then omits the multipart `model`
field. An empty model remains invalid unless omission is explicit.

## Native bindings

- ABI header: `rust/include/dart_edge_openai_audio_client.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_openai_audio_client run ffigen --config tool/ffigen.yaml
```

Validate the package:

```sh
cargo check --manifest-path packages/dart_edge_openai_audio_client/rust/Cargo.toml
dart test packages/dart_edge_openai_audio_client
```
