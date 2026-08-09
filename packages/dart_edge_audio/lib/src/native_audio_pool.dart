import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as native_bridge;

import 'audio_bytes_conversion_request.dart';
import 'audio_bytes_conversion_result.dart';
import 'audio_channel_layout.dart';
import 'audio_file_conversion_request.dart';
import 'audio_file_conversion_result.dart';
import 'audio_metadata.dart';
import 'audio_probe_mode.dart';
import 'audio_target_format.dart';
import 'native/dart_edge_audio_native.dart';
import 'native/generated_bindings.dart' as gen;
import 'native_audio_stream_conversion_result.dart';
import 'native_audio_stream_input.dart';

final class NativeAudioPoolMetrics {
  const NativeAudioPoolMetrics({
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

  factory NativeAudioPoolMetrics.fromJson(Map<String, Object?> json) {
    return NativeAudioPoolMetrics(
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

final class NativeAudioPool {
  factory NativeAudioPool({int workerCount = 4, int? maxQueueSize}) {
    RangeError.checkValueInInterval(workerCount, 1, 128, 'workerCount');
    final resolvedQueueSize = maxQueueSize ?? workerCount * 16;
    RangeError.checkValueInInterval(
      resolvedQueueSize,
      1,
      65536,
      'maxQueueSize',
    );

    DartEdgeAudioNative.initializeDartApiDl();
    final completionPort = native_bridge.NativeCompletionPort();
    final pool = NativeAudioPool._(
      poolPtr: DartEdgeAudioNative.createPool(
        workerCount: workerCount,
        maxQueueSize: resolvedQueueSize,
        completionPort: completionPort.nativePort,
      ),
      completionPort: completionPort,
      workerCount: workerCount,
      maxQueueSize: resolvedQueueSize,
    );
    pool._completionSubscription = completionPort.completedJobIds.listen(
      pool._handleCompletedJob,
      onError: pool._handleCompletionError,
    );
    return pool;
  }

  NativeAudioPool._({
    required this._poolPtr,
    required this._completionPort,
    required this.workerCount,
    required this.maxQueueSize,
  });

  final int workerCount;
  final int maxQueueSize;

  Pointer<gen.DartEdgeAudioPool> _poolPtr;
  final native_bridge.NativeCompletionPort _completionPort;
  late final StreamSubscription<int> _completionSubscription;
  final _pendingJobs = <int, _PendingAudioJob>{};
  bool _closed = false;

  Future<void> initialize() async {
    await Future.wait([
      for (var i = 0; i < workerCount; i += 1)
        probeBytes(
          _warmupWav16KhzMono,
          fileNameHint: 'audio-warmup.wav',
          mimeTypeHint: 'audio/wav',
          mode: AudioProbeMode.shallow,
        ),
    ]);
  }

  NativeAudioPoolMetrics get metrics {
    _ensureOpen();
    return NativeAudioPoolMetrics.fromJson(
      jsonDecode(DartEdgeAudioNative.readPoolMetrics(_poolPtr))
          as Map<String, Object?>,
    );
  }

  Future<AudioMetadata> probeFile(
    String path, {
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureOpen();
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be empty.');
    }
    final jobId = DartEdgeAudioNative.submitPoolProbeFile(
      _poolPtr,
      jsonEncode({'path': path, 'mode': mode.wireValue}),
    );
    final resultJson = await _waitForResult<String>(jobId, _AudioJobKind.file);
    return AudioMetadata.fromJson(
      jsonDecode(resultJson) as Map<String, Object?>,
    );
  }

  Future<AudioMetadata> probeBytes(
    Uint8List bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureOpen();
    _ensureBytes(bytes);
    final jobId = DartEdgeAudioNative.submitPoolProbeBytes(
      _poolPtr,
      jsonEncode({
        'fileNameHint': fileNameHint,
        'mimeTypeHint': mimeTypeHint,
        'mode': mode.wireValue,
      }),
      bytes,
    );
    final resultJson = await _waitForResult<String>(jobId, _AudioJobKind.probe);
    return AudioMetadata.fromJson(
      jsonDecode(resultJson) as Map<String, Object?>,
    );
  }

  Future<AudioMetadata> probeNativeBytes(
    native_bridge.NativeBytes bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureOpen();
    _ensureNativeBytes(bytes);
    final jobId = DartEdgeAudioNative.submitPoolProbeNativeBytes(
      _poolPtr,
      jsonEncode({
        'fileNameHint': fileNameHint,
        'mimeTypeHint': mimeTypeHint,
        'mode': mode.wireValue,
      }),
      bytes.ptr.cast<Uint8>(),
      bytes.len,
    );
    final resultJson = await _waitForResult<String>(jobId, _AudioJobKind.probe);
    return AudioMetadata.fromJson(
      jsonDecode(resultJson) as Map<String, Object?>,
    );
  }

  Future<AudioBytesConversionResult> convertBytes(
    AudioBytesConversionRequest request,
  ) async {
    _ensureOpen();
    _ensureBytes(request.inputBytes);
    _ensurePositiveSampleRate(request.targetSampleRate);
    final jobId = DartEdgeAudioNative.submitPoolConvertBytes(
      _poolPtr,
      jsonEncode(request.toJson()),
      request.inputBytes,
    );
    final response = await _waitForResult<NativeBytesConversionResponse>(
      jobId,
      _AudioJobKind.convert,
    );
    return AudioBytesConversionResult.fromJson(
      jsonDecode(response.resultJson) as Map<String, Object?>,
      bytes: response.bytes,
    );
  }

  Future<AudioFileConversionResult> convertFile(
    AudioFileConversionRequest request,
  ) async {
    _ensureOpen();
    _ensureFileRequest(request);
    final jobId = DartEdgeAudioNative.submitPoolConvertFile(
      _poolPtr,
      jsonEncode(request.toJson()),
    );
    final resultJson = await _waitForResult<String>(jobId, _AudioJobKind.file);
    return AudioFileConversionResult.fromJson(
      jsonDecode(resultJson) as Map<String, Object?>,
    );
  }

  Future<AudioBytesConversionResult> convertNativeBytes({
    required native_bridge.NativeBytes bytes,
    required AudioTargetFormat targetFormat,
    int? targetSampleRate,
    AudioChannelLayout channelLayout = AudioChannelLayout.keepSource,
    String? fileNameHint,
    String? mimeTypeHint,
  }) async {
    _ensureOpen();
    _ensureNativeBytes(bytes);
    _ensurePositiveSampleRate(targetSampleRate);
    final jobId = DartEdgeAudioNative.submitPoolConvertNativeBytes(
      _poolPtr,
      jsonEncode({
        'targetFormat': targetFormat.wireValue,
        'targetSampleRate': targetSampleRate,
        'channelLayout': channelLayout.wireValue,
        'fileNameHint': fileNameHint,
        'mimeTypeHint': mimeTypeHint,
      }),
      bytes.ptr.cast<Uint8>(),
      bytes.len,
    );
    final response = await _waitForResult<NativeBytesConversionResponse>(
      jobId,
      _AudioJobKind.convert,
    );
    return AudioBytesConversionResult.fromJson(
      jsonDecode(response.resultJson) as Map<String, Object?>,
      bytes: response.bytes,
    );
  }

  /// Normalizes native audio streams and concatenates them into one native WAV.
  ///
  /// Input bodies are consumed when the job is submitted. The returned body is
  /// backed by anonymous temporary storage and can be transferred directly to
  /// a compatible native HTTP response without materializing audio in Dart.
  Future<NativeAudioStreamConversionResult> concatenateStreams({
    required List<NativeAudioStreamInput> inputs,
    required AudioTargetFormat targetFormat,
    int? targetSampleRate,
    AudioChannelLayout channelLayout = AudioChannelLayout.keepSource,
  }) async {
    _ensureOpen();
    if (inputs.isEmpty) {
      throw ArgumentError.value(
        inputs,
        'inputs',
        'At least one native audio stream is required.',
      );
    }
    _ensurePositiveSampleRate(targetSampleRate);
    final jobId = DartEdgeAudioNative.submitPoolConcatenateStreams(
      _poolPtr,
      jsonEncode({
        'targetFormat': targetFormat.wireValue,
        'targetSampleRate': targetSampleRate,
        'channelLayout': channelLayout.wireValue,
      }),
      [
        for (final input in inputs)
          (
            body: input.body,
            fileNameHint: input.fileNameHint,
            mimeTypeHint: input.mimeTypeHint,
          ),
      ],
    );
    final response = await _waitForResult<NativeStreamConversionResponse>(
      jobId,
      _AudioJobKind.stream,
    );
    final body = native_bridge.NativeByteStreamHandle.fromAddresses(
      response.descriptor,
    );
    try {
      return NativeAudioStreamConversionResult.fromJson(
        jsonDecode(response.resultJson) as Map<String, Object?>,
        body: body,
        contentLength: response.contentLength,
      );
    } catch (_) {
      await body.close();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    final pendingJobs = List<_PendingAudioJob>.of(_pendingJobs.values);
    _pendingJobs.clear();
    DartEdgeAudioNative.freePool(_poolPtr);
    _poolPtr = nullptr;
    _closed = true;
    await _completionSubscription.cancel();
    await _completionPort.close();

    for (final job in pendingJobs) {
      job.completeError(StateError('Native audio pool is closed.'));
    }
  }

  Future<T> _waitForResult<T>(int jobId, _AudioJobKind kind) {
    _ensureOpen();
    final completer = Completer<Object>();
    _pendingJobs[jobId] = _PendingAudioJob(kind: kind, completer: completer);
    return completer.future.then((value) => value as T);
  }

  void _handleCompletedJob(int jobId) {
    final job = _pendingJobs.remove(jobId);
    if (job == null || _closed) {
      return;
    }

    try {
      final result = switch (job.kind) {
        _AudioJobKind.file => DartEdgeAudioNative.takePoolFileResult(
          _poolPtr,
          jobId,
        ),
        _AudioJobKind.probe => DartEdgeAudioNative.takePoolProbeResult(
          _poolPtr,
          jobId,
        ),
        _AudioJobKind.convert => DartEdgeAudioNative.takePoolConvertResult(
          _poolPtr,
          jobId,
        ),
        _AudioJobKind.stream => DartEdgeAudioNative.takePoolStreamResult(
          _poolPtr,
          jobId,
        ),
      };
      job.complete(result);
    } catch (error, stackTrace) {
      job.completeError(error, stackTrace);
    }
  }

  void _handleCompletionError(Object error, StackTrace stackTrace) {
    final pendingJobs = List<_PendingAudioJob>.of(_pendingJobs.values);
    _pendingJobs.clear();
    for (final job in pendingJobs) {
      job.completeError(error, stackTrace);
    }
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Native audio pool is closed.');
    }
  }
}

enum _AudioJobKind { file, probe, convert, stream }

final class _PendingAudioJob {
  const _PendingAudioJob({required this.kind, required this.completer});

  final _AudioJobKind kind;
  final Completer<Object> completer;

  void complete(Object value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }
}

void _ensureBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw ArgumentError.value(
      bytes,
      'bytes',
      'Audio byte input must not be empty.',
    );
  }
}

void _ensureFileRequest(AudioFileConversionRequest request) {
  if (request.inputPath.isEmpty) {
    throw ArgumentError.value(
      request.inputPath,
      'request.inputPath',
      'inputPath must not be empty.',
    );
  }
  if (request.outputPath.isEmpty) {
    throw ArgumentError.value(
      request.outputPath,
      'request.outputPath',
      'outputPath must not be empty.',
    );
  }
  _ensurePositiveSampleRate(request.targetSampleRate);
}

void _ensureNativeBytes(native_bridge.NativeBytes bytes) {
  if (bytes.ptr == nullptr || bytes.len <= 0) {
    throw ArgumentError.value(
      bytes,
      'bytes',
      'Audio byte input must not be empty.',
    );
  }
}

void _ensurePositiveSampleRate(int? sampleRate) {
  if (sampleRate case final sampleRate? when sampleRate < 1) {
    throw ArgumentError.value(
      sampleRate,
      'sampleRate',
      'sampleRate must be at least 1.',
    );
  }
}

final _warmupWav16KhzMono = Uint8List.fromList(const <int>[
  0x52,
  0x49,
  0x46,
  0x46,
  0x26,
  0x00,
  0x00,
  0x00,
  0x57,
  0x41,
  0x56,
  0x45,
  0x66,
  0x6d,
  0x74,
  0x20,
  0x10,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x01,
  0x00,
  0x80,
  0x3e,
  0x00,
  0x00,
  0x00,
  0x7d,
  0x00,
  0x00,
  0x02,
  0x00,
  0x10,
  0x00,
  0x64,
  0x61,
  0x74,
  0x61,
  0x02,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
]);
