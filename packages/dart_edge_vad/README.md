# dart_edge_vad

Voice activity detection and audio trimming APIs for Dart Edge.

The package exposes native voice activity detection and trimming APIs. It
currently ships Silero VAD v6.2.1 as the default native model, implemented with
ONNX inference in Rust plus PCM/WAV trimming in Dart. Input must be 16 kHz mono
PCM.

## Quick Start

```dart
import 'dart:typed_data';

import 'package:dart_edge_vad/dart_edge_vad.dart';

Future<void> main() async {
  final pcm = Int16List(16000);
  final wav = Uint8List(44);

  final vad = NativeVad(workerCount: 4);
  await vad.initialize();
  final result = await vad.detect(
    pcm16KhzMono: pcm,
    sampleRateHz: 16000,
  );

  if (result.hasSpeech) {
    final trimmed = AudioTrimmer.trimBySegments(wav, result.segments);
    print(trimmed.length);
  }

  await vad.close();
}
```

## Main Types

- `NativeVad`: native-thread detector with an internal bounded worker pool
- `NativeVadPoolMetrics`: native worker pool counters exposed by
  `NativeVad.metrics`
- `NativeVadStreamingSession`: stateful chunked detector for low-latency input
- `NativePcm16Buffer`: native-memory PCM16 input buffer for avoiding wrapper
  copies before FFI
- `NativeVadModel`: supported native model enum, currently `silero`
- `NativeVadOptions`: threshold and segment post-processing tunables
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

`NativeVad` owns a bounded Rust worker-thread pool. Requests are queued and
executed inside the native library; each worker owns one ONNX Runtime session.
Create one detector during application startup, call `initialize()` to warm the
workers, reuse it for requests, and call `close()` during shutdown.

`NativeVad.metrics` returns a point-in-time snapshot of worker count, queue
size, submitted/accepted/rejected jobs, active/queued jobs, completed jobs, and
completion notification failures. The current queue is bounded FIFO and
non-blocking: when the queue is full, submission fails immediately instead of
blocking or dropping older work.

For live audio, use `NativeVadStreamingSession` and feed 16 kHz mono PCM16
chunks. The native stream keeps recurrent model state between calls and only
emits newly finalized segments.

Native transport-lease methods call VAD synchronously without an intermediate
byte copy. Use `addBorrowedLease` when the same native transport payload must
remain available for an audio spool afterward. The lease remains owned by the
caller. Input is required to be 16 kHz mono PCM16LE; normalize other formats
incrementally before VAD. Ordinary Dart typed lists use the safe copying path.

For capture pipelines that already produce native memory, `NativePcm16Buffer`
remains available through `detectNativeBuffer`, `addNativeChunk`, and
`finishNative`.

## Benchmarks

Run the package-local throughput benchmark with generated silence or a 16 kHz
mono WAV file:

```sh
dart run packages/dart_edge_vad/tool/vad_throughput_benchmark.dart \
  --worker-count 8 \
  --concurrency 32 \
  --iterations 256
```

Use `--file path/to/input.wav` to benchmark a real normalized sample. The tool
prints JSON with wall duration, throughput, and request latency percentiles.
