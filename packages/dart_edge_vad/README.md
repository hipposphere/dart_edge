# dart_edge_vad

Voice activity detection and audio trimming APIs for Dart Edge.

The package exposes the app-facing API for Silero VAD trimming and implements
Silero ONNX inference in Rust plus PCM/WAV trimming in Dart. The bundled model
targets Silero VAD v6.2.1 and expects 16 kHz mono PCM input.

## Quick Start

```dart
import 'dart:typed_data';

import 'package:dart_edge_vad/dart_edge_vad.dart';

Future<void> main() async {
  final pcm = Int16List(16000);
  final wav = Uint8List(44);

  final Vad vad = SileroVad();
  final result = await vad.detect(
    pcm16KhzMono: pcm,
    sampleRateHz: 16000,
  );

  if (result.hasSpeech) {
    final trimmed = AudioTrimmer.trimBySegments(wav, result.segments);
    print(trimmed.length);
  }
}
```

## Main Types

- `SileroVad`: app-facing detector facade
- `SileroVadWorker`: long-lived isolate-backed detector for repeated requests
- `SileroVadStreamingSession`: stateful chunked detector for low-latency input
- `NativePcm16Buffer`: native-memory PCM16 input buffer for avoiding wrapper
  copies before FFI
- `SileroVadModel`: supported Silero model metadata
- `SileroVadOptions`: threshold and segment post-processing tunables
- `Vad`: detector interface for alternate VAD implementations
- `VadResult` and `VadSegment`: speech detection output
- `AudioTrimmer`: PCM16 and WAV trimming helpers
- `WavAudio`: small PCM WAV parser used by the trimmer

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_vad.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_vad run ffigen --config tool/ffigen.yaml
```

## Latency Notes

`SileroVad.detect` remains the simplest API and offloads work with
`Isolate.run`. For repeated calls, prefer `SileroVadWorker.spawn()` so the
worker isolate stays alive. For live audio, prefer `SileroVadStreamingSession`
and feed 16 kHz mono PCM16 chunks; the native stream keeps Silero state between
calls and only emits newly finalized segments.

Native Silero sessions are pooled. Set `DART_EDGE_VAD_SESSION_POOL_SIZE` to tune
the maximum number of concurrent ONNX sessions; by default the pool is capped at
four sessions.

Call `initialize()` during application startup to pay native ONNX cold-start
latency before real audio arrives. `SileroVad.initialize(sessionCount: n)` warms
multiple native sessions for concurrent traffic, and
`SileroVadWorker.spawn(initialize: true)` warms a long-lived worker before it is
returned.

The standard `Int16List` APIs copy Dart heap memory into native memory before
calling FFI because ordinary Dart typed lists do not expose stable C pointers.
For capture or streaming pipelines that can write directly into native memory,
use `NativePcm16Buffer` with `detectNativeBuffer`, `addNativeChunk`, or
`finishNative` to avoid that wrapper copy.
