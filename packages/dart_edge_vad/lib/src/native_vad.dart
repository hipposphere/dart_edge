import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as native_bridge;

import 'native/dart_edge_vad_native.dart';
import 'native/generated_bindings.dart' as gen;
import 'native_pcm16_buffer.dart';
import 'vad.dart';
import 'vad_result.dart';

/// Native VAD model backend.
enum NativeVadModel {
  /// Silero VAD v6.2.1 ONNX model.
  silero,
}

/// Metadata for supported native VAD models.
extension NativeVadModelMetadata on NativeVadModel {
  /// Native model version encoded in the Rust request payload.
  String get version {
    return switch (this) {
      NativeVadModel.silero => '6.2.1',
    };
  }

  /// Required PCM input sample rate.
  int get sampleRateHz {
    return switch (this) {
      NativeVadModel.silero => 16000,
    };
  }

  /// Number of samples per inference window.
  int get windowSizeSamples {
    return switch (this) {
      NativeVadModel.silero => 512,
    };
  }
}

/// Timestamp post-processing tunables for native VAD.
final class NativeVadOptions {
  const NativeVadOptions({
    this.threshold = 0.5,
    this.negThreshold,
    this.minSpeechDuration = const Duration(milliseconds: 250),
    this.minSilenceDuration = const Duration(milliseconds: 100),
    this.speechPad = const Duration(milliseconds: 30),
  }) : assert(threshold > 0 && threshold < 1),
       assert(negThreshold == null || negThreshold > 0),
       assert(negThreshold == null || negThreshold < threshold);

  final double threshold;
  final double? negThreshold;
  final Duration minSpeechDuration;
  final Duration minSilenceDuration;
  final Duration speechPad;

  double get resolvedNegThreshold => negThreshold ?? threshold - 0.15;
}

/// Point-in-time native worker pool counters.
final class NativeVadPoolMetrics {
  const NativeVadPoolMetrics({
    required this.workerCount,
    required this.maxQueueSize,
    required this.submittedJobs,
    required this.acceptedJobs,
    required this.rejectedQueueFullJobs,
    required this.rejectedClosedJobs,
    required this.startedJobs,
    required this.completedSuccessJobs,
    required this.completedErrorJobs,
    required this.pendingResultCount,
    required this.queuedJobs,
    required this.activeJobs,
    required this.maxObservedQueuedJobs,
    required this.maxObservedActiveJobs,
    required this.completionPostFailedJobs,
  });

  factory NativeVadPoolMetrics.fromJson(Map<String, Object?> json) {
    return NativeVadPoolMetrics(
      workerCount: json['workerCount'] as int,
      maxQueueSize: json['maxQueueSize'] as int,
      submittedJobs: json['submittedJobs'] as int,
      acceptedJobs: json['acceptedJobs'] as int,
      rejectedQueueFullJobs: json['rejectedQueueFullJobs'] as int,
      rejectedClosedJobs: json['rejectedClosedJobs'] as int,
      startedJobs: json['startedJobs'] as int,
      completedSuccessJobs: json['completedSuccessJobs'] as int,
      completedErrorJobs: json['completedErrorJobs'] as int,
      pendingResultCount: json['pendingResultCount'] as int,
      queuedJobs: json['queuedJobs'] as int,
      activeJobs: json['activeJobs'] as int,
      maxObservedQueuedJobs: json['maxObservedQueuedJobs'] as int,
      maxObservedActiveJobs: json['maxObservedActiveJobs'] as int,
      completionPostFailedJobs: json['completionPostFailedJobs'] as int,
    );
  }

  final int workerCount;
  final int maxQueueSize;
  final int submittedJobs;
  final int acceptedJobs;
  final int rejectedQueueFullJobs;
  final int rejectedClosedJobs;
  final int startedJobs;
  final int completedSuccessJobs;
  final int completedErrorJobs;
  final int pendingResultCount;
  final int queuedJobs;
  final int activeJobs;
  final int maxObservedQueuedJobs;
  final int maxObservedActiveJobs;
  final int completionPostFailedJobs;
}

/// Native-thread VAD detector.
///
/// One detector owns a bounded native worker pool. Each native worker owns one
/// ONNX Runtime session and reuses it for every job handled by that thread.
final class NativeVad implements Vad {
  factory NativeVad({
    NativeVadModel model = NativeVadModel.silero,
    NativeVadOptions options = const NativeVadOptions(),
    int workerCount = 4,
    int? maxQueueSize,
  }) {
    RangeError.checkValueInInterval(workerCount, 1, 128, 'workerCount');
    final resolvedQueueSize = maxQueueSize ?? workerCount * 16;
    RangeError.checkValueInInterval(
      resolvedQueueSize,
      1,
      65536,
      'maxQueueSize',
    );

    DartEdgeVadNative.initializeDartApiDl();
    final completionPort = native_bridge.NativeCompletionPort();
    final vad = NativeVad._(
      poolPtr: DartEdgeVadNative.createSileroPool(
        workerCount: workerCount,
        maxQueueSize: resolvedQueueSize,
        completionPort: completionPort.nativePort,
      ),
      completionPort: completionPort,
      workerCount: workerCount,
      maxQueueSize: resolvedQueueSize,
      model: model,
      options: options,
    );
    vad._completionSubscription = completionPort.completedJobIds.listen(
      vad._handleCompletedJob,
      onError: vad._handleCompletionError,
    );
    return vad;
  }

  NativeVad._({
    required this._poolPtr,
    required this._completionPort,
    required this.workerCount,
    required this.maxQueueSize,
    required this.model,
    required this.options,
  });

  final int workerCount;
  final int maxQueueSize;
  final NativeVadModel model;
  final NativeVadOptions options;

  Pointer<gen.DartEdgeVadPool> _poolPtr;
  final native_bridge.NativeCompletionPort _completionPort;
  late final StreamSubscription<int> _completionSubscription;
  final _pendingJobs = <int, _PendingVadJob>{};
  bool _closed = false;

  /// Warm all native workers before real requests arrive.
  Future<void> initialize() async {
    final warmup = Int16List(model.windowSizeSamples);
    await Future.wait([
      for (var i = 0; i < workerCount; i += 1)
        detect(pcm16KhzMono: warmup, sampleRateHz: model.sampleRateHz),
    ]);
  }

  /// Returns a point-in-time snapshot of native worker pool counters.
  NativeVadPoolMetrics get metrics {
    _ensureOpen();
    return NativeVadPoolMetrics.fromJson(
      jsonDecode(DartEdgeVadNative.readSileroPoolMetrics(_poolPtr))
          as Map<String, Object?>,
    );
  }

  @override
  Future<VadResult> detect({
    required Int16List pcm16KhzMono,
    required int sampleRateHz,
  }) async {
    _ensureOpen();
    _ensureSampleRate(sampleRateHz);

    final bytes = Uint8List.view(
      pcm16KhzMono.buffer,
      pcm16KhzMono.offsetInBytes,
      pcm16KhzMono.lengthInBytes,
    );
    final jobId = DartEdgeVadNative.submitSileroPool(
      _poolPtr,
      nativeVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
      bytes,
    );
    return _waitForResult(
      jobId,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: pcm16KhzMono.length,
    );
  }

  /// Detect speech from a native-memory PCM16 buffer without copying the input
  /// in the Dart FFI wrapper.
  Future<VadResult> detectNativeBuffer({
    required NativePcm16Buffer pcm16KhzMono,
    required int sampleRateHz,
  }) {
    return detectNativePointer(
      pcm16BytesPtr: pcm16KhzMono.bytesPtr,
      pcm16ByteLength: pcm16KhzMono.byteLength,
      sampleLength: pcm16KhzMono.sampleLength,
      sampleRateHz: sampleRateHz,
    );
  }

  /// Detect speech from native PCM16 bytes.
  ///
  /// The pointer must remain valid until the returned future completes.
  Future<VadResult> detectNativePointer({
    required Pointer<Uint8> pcm16BytesPtr,
    required int pcm16ByteLength,
    required int sampleLength,
    required int sampleRateHz,
  }) async {
    _ensureOpen();
    _ensureSampleRate(sampleRateHz);
    RangeError.checkNotNegative(pcm16ByteLength, 'pcm16ByteLength');
    RangeError.checkNotNegative(sampleLength, 'sampleLength');
    if (pcm16ByteLength != sampleLength * 2) {
      throw ArgumentError.value(
        pcm16ByteLength,
        'pcm16ByteLength',
        'PCM16 byte length must be exactly sampleLength * 2.',
      );
    }

    final jobId = DartEdgeVadNative.submitSileroPoolNativePointer(
      _poolPtr,
      nativeVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
      pcm16BytesPtr,
      pcm16ByteLength,
    );
    return _waitForResult(
      jobId,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: sampleLength,
    );
  }

  /// Frees the native worker pool.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    final pendingJobs = List<_PendingVadJob>.of(_pendingJobs.values);
    _pendingJobs.clear();
    DartEdgeVadNative.freeSileroPool(_poolPtr);
    _poolPtr = nullptr;
    _closed = true;
    await _completionSubscription.cancel();
    await _completionPort.close();

    for (final job in pendingJobs) {
      job.completer.completeError(StateError('Native VAD detector is closed.'));
    }
  }

  Future<VadResult> _waitForResult(
    int jobId, {
    required int expectedSampleRateHz,
    required int expectedTotalSamples,
  }) {
    _ensureOpen();
    final completer = Completer<VadResult>();
    _pendingJobs[jobId] = _PendingVadJob(
      completer: completer,
      expectedSampleRateHz: expectedSampleRateHz,
      expectedTotalSamples: expectedTotalSamples,
    );
    return completer.future;
  }

  void _handleCompletedJob(int jobId) {
    final job = _pendingJobs.remove(jobId);
    if (job == null || _closed) {
      return;
    }

    try {
      final resultJson = DartEdgeVadNative.takeSileroPoolResult(
        _poolPtr,
        jobId,
      );
      job.completer.complete(
        readVadResult(
          jsonDecode(resultJson) as Map<String, Object?>,
          expectedSampleRateHz: job.expectedSampleRateHz,
          expectedTotalSamples: job.expectedTotalSamples,
        ),
      );
    } catch (error, stackTrace) {
      job.completer.completeError(error, stackTrace);
    }
  }

  void _handleCompletionError(Object error, StackTrace stackTrace) {
    final pendingJobs = List<_PendingVadJob>.of(_pendingJobs.values);
    _pendingJobs.clear();
    for (final job in pendingJobs) {
      job.completer.completeError(error, stackTrace);
    }
  }

  void _ensureSampleRate(int sampleRateHz) {
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Native VAD model ${model.name} expects ${model.sampleRateHz} Hz audio.',
      );
    }
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Native VAD detector is closed.');
    }
  }
}

final class _PendingVadJob {
  const _PendingVadJob({
    required this.completer,
    required this.expectedSampleRateHz,
    required this.expectedTotalSamples,
  });

  final Completer<VadResult> completer;
  final int expectedSampleRateHz;
  final int expectedTotalSamples;
}

String nativeVadRequestJson({
  required NativeVadModel model,
  required NativeVadOptions options,
  required int sampleRateHz,
}) {
  return jsonEncode({
    'modelVersion': model.version,
    'sampleRateHz': sampleRateHz,
    'windowSizeSamples': model.windowSizeSamples,
    'threshold': options.threshold,
    'negThreshold': options.resolvedNegThreshold,
    'minSpeechDurationMs': options.minSpeechDuration.inMilliseconds,
    'minSilenceDurationMs': options.minSilenceDuration.inMilliseconds,
    'speechPadMs': options.speechPad.inMilliseconds,
  });
}

VadResult readVadResult(
  Map<String, Object?> json, {
  required int expectedSampleRateHz,
  required int expectedTotalSamples,
}) {
  final sampleRateHz = json['sampleRateHz'] as int? ?? expectedSampleRateHz;
  final totalSamples = json['totalSamples'] as int? ?? expectedTotalSamples;
  final rawSegments = json['segments'] as List<Object?>? ?? const <Object?>[];
  final segments = rawSegments.map((rawSegment) {
    final segment = rawSegment as Map<String, Object?>;
    return VadSegment(
      startSample: segment['startSample'] as int,
      endSample: segment['endSample'] as int,
      sampleRateHz: sampleRateHz,
    );
  }).toList();

  return VadResult(
    segments: segments,
    sampleRateHz: sampleRateHz,
    totalSamples: totalSamples,
  );
}
