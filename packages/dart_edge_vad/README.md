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
