# dart_edge_audio

Native-backed audio probing and conversion utilities for Dart Edge.

This package provides coarse-grained audio helpers for reading metadata and
normalizing supported inputs into PCM WAV output. It is a standalone utility
package and does not depend on `dart_edge_http_server_runtime`.

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
- `DartEdgeAudio.probeNativeBytes` and `DartEdgeAudio.convertNativeBytes`
  accept borrowed `dart_edge_core` `NativeBytes` for zero-copy input handoff
- `AudioMetadata` describes the decoded source or output asset
- `AudioFileConversionRequest` and `AudioBytesConversionRequest` configure WAV
  conversion
- `AudioTargetFormat` currently supports `wavPcm16` and `wavPcm24`
- `NativeAudioPool.concatenateStreams` normalizes single-owner native inputs
  into an anonymous-file-backed WAV stream without materializing payloads in
  Dart memory

## Native Bytes Fast Path

When audio input already lives in native memory, for example as a borrowed
request body from another Dart Edge runtime package, prefer the `NativeBytes`
entrypoints from `dart_edge_core/ffi.dart` to avoid an extra Dart-side copy
before the Rust audio worker runs.

```dart
import 'package:dart_edge_audio/dart_edge_audio.dart';
import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart' as core_ffi;

Future<AudioMetadata> inspectBorrowedAudio(core_ffi.NativeBytes bytes) {
  return DartEdgeAudio.probeNativeBytes(
    bytes,
    fileNameHint: 'upload.mp3',
    mimeTypeHint: 'audio/mpeg',
  );
}
```

## Native Stream Concatenation

Use native stream concatenation when inputs already come from a compatible
native producer such as `dart_edge_s3_client`. Input handles are consumed when
the job is submitted. The result can be transferred directly into a compatible
native HTTP response.

```dart
final result = await audioPool.concatenateStreams(
  inputs: downloads
      .map(
        (download) => NativeAudioStreamInput(
          body: download.body,
          fileNameHint: download.fileName,
          mimeTypeHint: download.contentType,
        ),
      )
      .toList(),
  targetFormat: AudioTargetFormat.wavPcm16,
  targetSampleRate: 16000,
  channelLayout: AudioChannelLayout.mono,
);
```

The completed WAV is held in anonymous OS temporary storage. Its native body
is backpressured and automatically releases the temporary file when consumed,
canceled, or closed.

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_audio.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_audio run ffigen --config tool/ffigen.yaml
```
