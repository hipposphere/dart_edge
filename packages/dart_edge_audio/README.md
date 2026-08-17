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
- `NativeAudioWaveformSession` accumulates compact waveform peaks directly
  from streaming PCM16LE chunks
- `NativeAudioPcm16StreamSession` consumes transport payload leases into a
  bounded native PCM buffer and seals them as a transferable WAV stream
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

The completed WAV remains in native memory. Its native body is read in bounded
chunks and releases its backing storage when consumed, canceled, or closed.

## Streaming PCM16 Transport Ingress

Use `NativeAudioPcm16StreamSession` for WebSocket or WebTransport audio that is
already interleaved PCM16LE. `addLease` consumes every `BinaryPayloadLease` and
can skip a protocol header through `offset` without allocating a Dart-owned
audio copy.

```dart
final audioPool = NativeAudioPool(
  workerCount: 4,
  maxQueueSize: 32,
  maxActiveSpoolBytes: 512 * 1024 * 1024,
);
final audio = audioPool.createPcm16StreamSession(
  inputSampleRateHz: 48000,
  inputChannelCount: 2,
  targetSampleRateHz: 16000,
  channelLayout: AudioChannelLayout.mono,
  spoolPolicy: const AudioSpoolPolicy.adaptive(
    preferredMemoryBytes: 32 * 1024 * 1024,
    maxBytes: 64 * 1024 * 1024,
  ),
);

audio.addLease(frameLease, offset: protocolHeaderLength);

final wav = await audio.finish();
// Transfer wav.body into another native package, then use wav.contentLength.
```

The per-session and pool-wide spool ceilings are enforced before accepting each
frame. `NativeAudioPool.metrics` reports current, peak, and queued finishing
bytes. Adaptive spooling currently uses bounded native memory only and never
implicitly writes to disk. Future backends can be added behind the same policy
while remaining explicitly enabled. `finish` consumes the session and runs on
the pool's bounded worker queue before returning a native stream. Voice activity
detection remains owned by `dart_edge_vad` so applications can choose whether
and how to trim.

External native audio buffers can participate in the same hard ceiling. Reserve
their maximum size before creating them and release the token with the buffer:

```dart
final reservation = audioPool.reserveTransientBytes(256 * 1024);
final trimmer = NativeVadTrimmingSession(maxPendingBytes: reservation.bytes);
try {
  // Feed and drain the bounded native trimming session.
} finally {
  trimmer.close();
  reservation.close();
}
```

`reservedTransientBytes` and `maxObservedReservedTransientBytes` distinguish
these reservations in pool metrics while `currentSpoolBytes` continues to
represent the complete shared budget consumption.

## Streaming PCM16 Waveforms

Use `NativeAudioWaveformSession` when canonical PCM16LE audio is already
arriving incrementally. The accumulator retains only compact min/max peaks, not
the audio payload.

```dart
final waveform = NativeAudioWaveformSession(
  sampleRateHz: 16000,
  waveform: const AudioWaveformSpec(
    baseInterval: Duration(milliseconds: 20),
    levelFactors: [1, 4, 16],
  ),
);

waveform.addPcm16(chunk);
final result = waveform.finish();
```

`addPcm16` accepts Dart-managed `Uint8List` data and uses a temporary native
copy for the FFI call. When a transport or recorder already owns native bytes,
use `addNativePcm16` with its pointer and length. Rust reads the borrowed bytes
synchronously without retaining or copying the chunk.

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_audio.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
cd packages/dart_edge_audio
dart run ffigen --config tool/ffigen.yaml
```
