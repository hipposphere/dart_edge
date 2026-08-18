import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    show NativeBinaryPayloadLease;

import 'native/dart_edge_vad_native.dart';
import 'native/generated_bindings.dart' as gen;
import 'native_pcm16_buffer.dart';
import 'native_vad.dart';
import 'vad_result.dart';

/// Incremental output from a [NativeVadStreamingSession] call.
final class NativeVadStreamResult {
  const NativeVadStreamResult({
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
  /// a complete model window.
  final int totalSamples;

  /// Samples processed by ONNX inference.
  final int processedSamples;

  final bool hasSpeech;

  final bool finished;

  /// Per-window speech probabilities produced while processing this chunk.
  final List<double> probabilities;
}

/// Stateful native VAD session for chunked PCM16 input.
///
/// The native session keeps model recurrent state and context between calls, so
/// callers can feed window-sized chunks without repeatedly running VAD over the
/// entire accumulated audio.
final class NativeVadStreamingSession {
  NativeVadStreamingSession({
    this.model = NativeVadModel.silero,
    this.options = const NativeVadOptions(),
    this.sampleRateHz = 16000,
  }) {
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Native VAD model ${model.name} expects ${model.sampleRateHz} Hz audio.',
      );
    }
    _streamPtr = DartEdgeVadNative.createSileroStream(
      nativeVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
    );
  }

  final NativeVadModel model;

  final NativeVadOptions options;

  final int sampleRateHz;

  late final Pointer<gen.DartEdgeVadStream> _streamPtr;
  var _closed = false;

  /// Warm the native VAD inference path before real chunks arrive.
  ///
  /// This warms the native worker pool without mutating this stream's recurrent
  /// VAD state or sample offsets.
  Future<void> initialize() async {
    final vad = NativeVad(model: model, options: options, workerCount: 1);
    try {
      await vad.initialize();
    } finally {
      await vad.close();
    }
  }

  NativeVadStreamResult addChunk(Int16List pcm16KhzMono) {
    return _process(pcm16KhzMono, flush: false);
  }

  /// Processes bytes from [lease] without consuming or closing it.
  ///
  /// This lets a transport payload be inspected by VAD and then handed to an
  /// audio spool. [offset] and [length] must select complete PCM16 samples.
  NativeVadStreamResult addBorrowedLease(
    NativeBinaryPayloadLease lease, {
    int offset = 0,
    int? length,
  }) {
    return processBorrowedLease(
      lease,
      offset: offset,
      length: length,
      flush: false,
    );
  }

  NativeVadStreamResult addNativeChunk(NativePcm16Buffer pcm16KhzMono) {
    return processNativePointer(
      pcm16BytesPtr: pcm16KhzMono.bytesPtr,
      pcm16ByteLength: pcm16KhzMono.byteLength,
      flush: false,
    );
  }

  NativeVadStreamResult finish([Int16List? pcm16KhzMono]) {
    return _process(pcm16KhzMono ?? Int16List(0), flush: true);
  }

  NativeVadStreamResult finishBorrowedLease(
    NativeBinaryPayloadLease lease, {
    int offset = 0,
    int? length,
  }) {
    return processBorrowedLease(
      lease,
      offset: offset,
      length: length,
      flush: true,
    );
  }

  NativeVadStreamResult finishNative([NativePcm16Buffer? pcm16KhzMono]) {
    return processNativePointer(
      pcm16BytesPtr: pcm16KhzMono?.bytesPtr ?? nullptr,
      pcm16ByteLength: pcm16KhzMono?.byteLength ?? 0,
      flush: true,
    );
  }

  /// Process native PCM16 bytes without copying in the Dart FFI wrapper.
  NativeVadStreamResult processNativePointer({
    required Pointer<Uint8> pcm16BytesPtr,
    required int pcm16ByteLength,
    required bool flush,
  }) {
    if (_closed) {
      throw StateError('Native VAD streaming session is closed.');
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

  /// Processes a borrowed native lease without transferring its ownership.
  NativeVadStreamResult processBorrowedLease(
    NativeBinaryPayloadLease lease, {
    int offset = 0,
    int? length,
    required bool flush,
  }) {
    final selectedLength = length ?? lease.length - offset;
    RangeError.checkValidRange(
      offset,
      offset + selectedLength,
      lease.length,
      'offset',
    );
    if (selectedLength.isOdd) {
      throw ArgumentError.value(
        selectedLength,
        'length',
        'PCM16 byte length must be even.',
      );
    }
    return processNativePointer(
      pcm16BytesPtr: lease.bytesPtr + offset,
      pcm16ByteLength: selectedLength,
      flush: flush,
    );
  }

  void close() {
    if (_closed) {
      return;
    }
    DartEdgeVadNative.freeSileroStream(_streamPtr);
    _closed = true;
  }

  NativeVadStreamResult _process(
    Int16List pcm16KhzMono, {
    required bool flush,
  }) {
    if (_closed) {
      throw StateError('Native VAD streaming session is closed.');
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

NativeVadStreamResult _readStreamResult(Map<String, Object?> json) {
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

  return NativeVadStreamResult(
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
