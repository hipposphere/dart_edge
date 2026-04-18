# dart_edge_audio

Native-backed audio probing and conversion utilities for Dart Edge.

This package provides coarse-grained audio helpers for reading metadata and
normalizing supported inputs into PCM WAV output. It is a standalone utility
package and does not depend on `dart_edge_runtime`.

## Quick Start

```dart
import 'package:dart_edge_audio/dart_edge_audio.dart';

Future<void> main() async {
  final metadata = await DartEdgeAudio.probeFile('voice-note.mp3');

  final converted = await DartEdgeAudio.convertFile(
    AudioFileConversionRequest(
      inputPath: 'voice-note.mp3',
      outputPath: 'voice-note.wav',
      targetFormat: AudioTargetFormat.wavPcm16,
      targetSampleRate: 16000,
      channelLayout: AudioChannelLayout.mono,
      overwriteExisting: true,
    ),
  );

  print(metadata.codec);
  print(converted.outputPath);
}
```

## Main Types

- `DartEdgeAudio` exposes stateless async probe and conversion helpers
- `AudioMetadata` describes the decoded source or output asset
- `AudioFileConversionRequest` and `AudioBytesConversionRequest` configure WAV
  conversion
- `AudioTargetFormat` currently supports `wavPcm16` and `wavPcm24`

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_audio.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_audio run ffigen --config tool/ffigen.yaml
```
