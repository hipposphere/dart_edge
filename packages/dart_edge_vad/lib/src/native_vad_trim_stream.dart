import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    show NativeBinaryPayloadLease;
import 'package:ffi/ffi.dart';

import 'native/dart_edge_vad_native.dart';
import 'native/generated_bindings.dart' as gen;
import 'native_vad.dart';
import 'vad_result.dart';

/// Maps one emitted trimmed PCM range back to its original input timeline.
final class NativeVadTrimmedRange {
  const NativeVadTrimmedRange({
    required this.sourceStartSample,
    required this.sourceEndSample,
    required this.outputStartSample,
    required this.outputEndSample,
  });

  final int sourceStartSample;
  final int sourceEndSample;
  final int outputStartSample;
  final int outputEndSample;

  int get sourceLengthSamples => sourceEndSample - sourceStartSample;
  int get outputLengthSamples => outputEndSample - outputStartSample;
}

/// One native-owned PCM16LE chunk released by a trimming session.
///
/// [bytesView] and [bytesPtr] remain valid until [close]. Consumers may borrow
/// them synchronously without copying, including native audio spools. Close the
/// chunk after every consumer has finished with it.
final class NativeVadTrimmedChunk {
  NativeVadTrimmedChunk._(
    this._resultPtr, {
    required this.bytesPtr,
    required this.byteLength,
  }) {
    _trimResultFinalizer.attach(this, _resultPtr.address, detach: this);
  }

  Pointer<gen.DartEdgeVadTrimProcessResult> _resultPtr;
  final Pointer<Uint8> bytesPtr;
  final int byteLength;
  var _closed = false;

  int get sampleLength => byteLength ~/ 2;
  bool get isClosed => _closed;

  Uint8List get bytesView {
    _ensureOpen();
    return byteLength == 0 ? Uint8List(0) : bytesPtr.asTypedList(byteLength);
  }

  Uint8List takeBytes() {
    final result = Uint8List.fromList(bytesView);
    close();
    return result;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _trimResultFinalizer.detach(this);
    DartEdgeVadNative.freeSileroTrimProcessResult(_resultPtr);
    _resultPtr = nullptr;
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Native VAD trimmed chunk is closed.');
  }
}

/// Incremental result from [NativeVadTrimmingSession].
final class NativeVadTrimUpdate {
  const NativeVadTrimUpdate({
    required this.chunk,
    required this.ranges,
    required this.segments,
    required this.sampleRateHz,
    required this.totalSamples,
    required this.processedSamples,
    required this.outputSamples,
    required this.bufferedBytes,
    required this.hasSpeech,
    required this.speechActive,
    required this.finished,
  });

  final NativeVadTrimmedChunk? chunk;
  final List<NativeVadTrimmedRange> ranges;
  final List<VadSegment> segments;
  final int sampleRateHz;
  final int totalSamples;
  final int processedSamples;
  final int outputSamples;
  final int bufferedBytes;
  final bool hasSpeech;
  final bool speechActive;
  final bool finished;
}

/// Native incremental VAD and PCM16LE trimming with bounded look-behind.
///
/// Speech PCM is released while speech is active. When silence begins, output
/// pauses until the VAD either observes resumed speech or confirms an endpoint.
/// This retains short pauses without adding a fixed delay to active speech and
/// removes long silent regions without staging complete utterances in Dart.
final class NativeVadTrimmingSession {
  NativeVadTrimmingSession({
    this.model = NativeVadModel.silero,
    this.options = const NativeVadOptions(),
    this.sampleRateHz = 16000,
    this.maxPendingBytes = 256 * 1024,
  }) {
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Native VAD model ${model.name} expects ${model.sampleRateHz} Hz audio.',
      );
    }
    RangeError.checkValueInInterval(
      maxPendingBytes,
      2,
      1 << 30,
      'maxPendingBytes',
    );
    if (maxPendingBytes.isOdd) {
      throw ArgumentError.value(
        maxPendingBytes,
        'maxPendingBytes',
        'Must be even.',
      );
    }
    final request = jsonDecode(
      nativeVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
    ) as Map<String, Object?>;
    request['maxPendingBytes'] = maxPendingBytes;
    _streamPtr = DartEdgeVadNative.createSileroTrimStream(jsonEncode(request));
    _trimStreamFinalizer.attach(this, _streamPtr.address, detach: this);
  }

  final NativeVadModel model;
  final NativeVadOptions options;
  final int sampleRateHz;
  final int maxPendingBytes;

  late Pointer<gen.DartEdgeVadTrimStream> _streamPtr;
  WeakReference<NativeVadTrimmedChunk>? _outstandingChunk;
  var _closed = false;

  /// Warms native inference without changing trim state or sample offsets.
  Future<void> initialize() async {
    _ensureCanProcess();
    final vad = NativeVad(model: model, options: options, workerCount: 1);
    try {
      await vad.initialize();
    } finally {
      await vad.close();
    }
  }

  NativeVadTrimUpdate addPcm16Bytes(Uint8List pcm16Bytes) =>
      _processBytes(pcm16Bytes, flush: false);

  NativeVadTrimUpdate addChunk(Int16List pcm16) => addPcm16Bytes(
    Uint8List.view(pcm16.buffer, pcm16.offsetInBytes, pcm16.lengthInBytes),
  );

  /// Borrows a transport lease without consuming or closing it.
  NativeVadTrimUpdate addBorrowedLease(
    BinaryPayloadLease lease, {
    int offset = 0,
    int? length,
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
    if (lease case NativeBinaryPayloadLease(:final bytesPtr)) {
      return processNativePointer(
        pcm16BytesPtr: bytesPtr + offset,
        pcm16ByteLength: selectedLength,
        flush: false,
      );
    }
    return addPcm16Bytes(
      Uint8List.sublistView(lease.bytesView, offset, offset + selectedLength),
    );
  }

  NativeVadTrimUpdate processNativePointer({
    required Pointer<Uint8> pcm16BytesPtr,
    required int pcm16ByteLength,
    required bool flush,
  }) {
    _ensureCanProcess();
    if (pcm16ByteLength.isOdd) {
      throw ArgumentError.value(
        pcm16ByteLength,
        'pcm16ByteLength',
        'PCM16 byte length must be even.',
      );
    }
    final resultPtr = DartEdgeVadNative.processSileroTrimStreamPointer(
      _streamPtr,
      pcm16BytesPtr,
      pcm16ByteLength,
      flush: flush,
    );
    return _readResult(resultPtr);
  }

  NativeVadTrimUpdate finish([Int16List? finalPcm16]) {
    final pcm16 = finalPcm16 ?? Int16List(0);
    return _processBytes(
      Uint8List.view(pcm16.buffer, pcm16.offsetInBytes, pcm16.lengthInBytes),
      flush: true,
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _trimStreamFinalizer.detach(this);
    DartEdgeVadNative.freeSileroTrimStream(_streamPtr);
    _streamPtr = nullptr;
  }

  NativeVadTrimUpdate _processBytes(
    Uint8List pcm16Bytes, {
    required bool flush,
  }) {
    _ensureCanProcess();
    if (pcm16Bytes.lengthInBytes.isOdd) {
      throw ArgumentError.value(
        pcm16Bytes.lengthInBytes,
        'pcm16Bytes',
        'PCM16 byte length must be even.',
      );
    }
    return _readResult(
      DartEdgeVadNative.processSileroTrimStream(
        _streamPtr,
        pcm16Bytes,
        flush: flush,
      ),
    );
  }

  NativeVadTrimUpdate _readResult(
    Pointer<gen.DartEdgeVadTrimProcessResult> resultPtr,
  ) {
    var ownsNativeResult = true;
    try {
      final native = resultPtr.ref;
      final json = jsonDecode(
        native.result_json.cast<Utf8>().toDartString(),
      ) as Map<String, Object?>;
      final sampleRate = json['sampleRateHz']! as int;
      final ranges = (json['ranges']! as List<Object?>)
          .map((value) {
            final range = value! as Map<String, Object?>;
            return NativeVadTrimmedRange(
              sourceStartSample: range['sourceStartSample']! as int,
              sourceEndSample: range['sourceEndSample']! as int,
              outputStartSample: range['outputStartSample']! as int,
              outputEndSample: range['outputEndSample']! as int,
            );
          })
          .toList(growable: false);
      final segments = (json['segments']! as List<Object?>)
          .map((value) {
            final segment = value! as Map<String, Object?>;
            return VadSegment(
              startSample: segment['startSample']! as int,
              endSample: segment['endSample']! as int,
              sampleRateHz: sampleRate,
            );
          })
          .toList(growable: false);
      final totalSamples = json['totalSamples']! as int;
      final processedSamples = json['processedSamples']! as int;
      final outputSamples = json['outputSamples']! as int;
      final bufferedBytes = json['bufferedBytes']! as int;
      final hasSpeech = json['hasSpeech']! as bool;
      final speechActive = json['speechActive']! as bool;
      final finished = json['finished']! as bool;
      final chunk = native.output_len == 0
          ? null
          : NativeVadTrimmedChunk._(
              resultPtr,
              bytesPtr: native.output_ptr,
              byteLength: native.output_len,
            );
      if (chunk != null) {
        _outstandingChunk = WeakReference(chunk);
      }
      if (chunk == null) {
        DartEdgeVadNative.freeSileroTrimProcessResult(resultPtr);
      }
      ownsNativeResult = false;
      return NativeVadTrimUpdate(
        chunk: chunk,
        ranges: ranges,
        segments: segments,
        sampleRateHz: sampleRate,
        totalSamples: totalSamples,
        processedSamples: processedSamples,
        outputSamples: outputSamples,
        bufferedBytes: bufferedBytes,
        hasSpeech: hasSpeech,
        speechActive: speechActive,
        finished: finished,
      );
    } catch (_) {
      if (ownsNativeResult) {
        DartEdgeVadNative.freeSileroTrimProcessResult(resultPtr);
      }
      rethrow;
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Native VAD trimming session is closed.');
  }

  void _ensureCanProcess() {
    _ensureOpen();
    final outstanding = _outstandingChunk?.target;
    if (outstanding != null && !outstanding.isClosed) {
      throw StateError('Close the previous native VAD trimmed chunk before adding more audio.');
    }
  }
}

final _trimStreamFinalizer = Finalizer<int>((address) {
  DartEdgeVadNative.freeSileroTrimStream(
    Pointer<gen.DartEdgeVadTrimStream>.fromAddress(address),
  );
});

final _trimResultFinalizer = Finalizer<int>((address) {
  DartEdgeVadNative.freeSileroTrimProcessResult(
    Pointer<gen.DartEdgeVadTrimProcessResult>.fromAddress(address),
  );
});
