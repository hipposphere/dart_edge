import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'native/dart_edge_vad_native.dart';
import 'native/generated_bindings.dart' as gen;
import 'native_pcm16_buffer.dart';
import 'silero_vad.dart';
import 'vad_result.dart';

/// Incremental output from a [SileroVadStreamingSession] call.
final class SileroVadStreamResult {
  const SileroVadStreamResult({
    required this.segments,
    required this.sampleRateHz,
    required this.totalSamples,
    required this.processedSamples,
    required this.hasSpeech,
    required this.finished,
    required this.probabilities,
  });

  /// Newly finalized speech segments from this chunk.
  final List<VadSegment> segments;

  final int sampleRateHz;

  /// Samples received by the stream, including samples not yet processed into
  /// a complete Silero window.
  final int totalSamples;

  /// Samples processed by ONNX inference.
  final int processedSamples;

  final bool hasSpeech;

  final bool finished;

  /// Per-window speech probabilities produced while processing this chunk.
  final List<double> probabilities;
}

/// Stateful Silero VAD session for chunked PCM16 input.
///
/// The native session keeps Silero recurrent state and context between calls,
/// so callers can feed 512-sample-or-larger chunks without repeatedly running
/// VAD over the entire accumulated audio.
final class SileroVadStreamingSession {
  SileroVadStreamingSession({
    this.model = SileroVadModel.latest,
    this.options = const SileroVadOptions(),
    this.sampleRateHz = 16000,
  }) {
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Silero VAD ${model.version} expects ${model.sampleRateHz} Hz audio.',
      );
    }
    _streamPtr = DartEdgeVadNative.createSileroStream(
      sileroVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
    );
  }

  final SileroVadModel model;

  final SileroVadOptions options;

  final int sampleRateHz;

  late final Pointer<gen.DartEdgeVadStream> _streamPtr;
  var _closed = false;

  /// Warm this stream's native Silero inference path before real chunks arrive.
  ///
  /// This warms the shared native session pool without mutating this stream's
  /// recurrent VAD state or sample offsets.
  Future<void> initialize() {
    return SileroVad(model: model, options: options).initialize();
  }

  SileroVadStreamResult addChunk(Int16List pcm16KhzMono) {
    return _process(pcm16KhzMono, flush: false);
  }

  SileroVadStreamResult addNativeChunk(NativePcm16Buffer pcm16KhzMono) {
    return processNativePointer(
      pcm16BytesPtr: pcm16KhzMono.bytesPtr,
      pcm16ByteLength: pcm16KhzMono.byteLength,
      flush: false,
    );
  }

  SileroVadStreamResult finish([Int16List? pcm16KhzMono]) {
    return _process(pcm16KhzMono ?? Int16List(0), flush: true);
  }

  SileroVadStreamResult finishNative([NativePcm16Buffer? pcm16KhzMono]) {
    return processNativePointer(
      pcm16BytesPtr: pcm16KhzMono?.bytesPtr ?? nullptr,
      pcm16ByteLength: pcm16KhzMono?.byteLength ?? 0,
      flush: true,
    );
  }

  /// Process native PCM16 bytes without copying in the Dart FFI wrapper.
  SileroVadStreamResult processNativePointer({
    required Pointer<Uint8> pcm16BytesPtr,
    required int pcm16ByteLength,
    required bool flush,
  }) {
    if (_closed) {
      throw StateError('Silero VAD streaming session is closed.');
    }

    final resultJson = DartEdgeVadNative.processSileroStreamPointer(
      _streamPtr,
      pcm16BytesPtr,
      pcm16ByteLength,
      flush: flush,
    );
    final json = jsonDecode(resultJson) as Map<String, Object?>;
    return _readStreamResult(json);
  }

  void close() {
    if (_closed) {
      return;
    }
    DartEdgeVadNative.freeSileroStream(_streamPtr);
    _closed = true;
  }

  SileroVadStreamResult _process(
    Int16List pcm16KhzMono, {
    required bool flush,
  }) {
    if (_closed) {
      throw StateError('Silero VAD streaming session is closed.');
    }

    final bytes = Uint8List.view(
      pcm16KhzMono.buffer,
      pcm16KhzMono.offsetInBytes,
      pcm16KhzMono.lengthInBytes,
    );
    final resultJson = DartEdgeVadNative.processSileroStream(
      _streamPtr,
      bytes,
      flush: flush,
    );
    final json = jsonDecode(resultJson) as Map<String, Object?>;
    return _readStreamResult(json);
  }
}

SileroVadStreamResult _readStreamResult(Map<String, Object?> json) {
  final sampleRateHz = json['sampleRateHz'] as int;
  final rawSegments = json['segments'] as List<Object?>? ?? const <Object?>[];
  final segments = rawSegments.map((rawSegment) {
    final segment = rawSegment as Map<String, Object?>;
    return VadSegment(
      startSample: segment['startSample'] as int,
      endSample: segment['endSample'] as int,
      sampleRateHz: sampleRateHz,
    );
  }).toList();
  final rawProbabilities =
      json['probabilities'] as List<Object?>? ?? const <Object?>[];

  return SileroVadStreamResult(
    segments: segments,
    sampleRateHz: sampleRateHz,
    totalSamples: json['totalSamples'] as int,
    processedSamples: json['processedSamples'] as int,
    hasSpeech: json['hasSpeech'] as bool? ?? segments.isNotEmpty,
    finished: json['finished'] as bool? ?? false,
    probabilities: rawProbabilities.cast<num>().map((value) {
      return value.toDouble();
    }).toList(),
  );
}
