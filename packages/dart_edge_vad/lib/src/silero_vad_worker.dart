import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';

import 'native/dart_edge_vad_native.dart';
import 'native_pcm16_buffer.dart';
import 'silero_vad.dart';
import 'vad.dart';
import 'vad_result.dart';

/// Long-lived isolate-backed Silero VAD detector.
///
/// Use this for repeated requests when the per-call [Isolate.run] overhead in
/// [SileroVad] is measurable. Native inference still uses the shared native
/// session pool, so multiple workers can run concurrently up to that pool size.
abstract base class _SileroVadWorkerBase implements Vad {
  const _SileroVadWorkerBase({required this.model, required this.options});

  final SileroVadModel model;

  final SileroVadOptions options;

  int get _warmupRequestCount => 1;

  Future<String> _request(List<Object?> request);

  /// Warm this worker's native Silero inference path before real requests.
  Future<void> initialize() async {
    final warmup = Int16List(model.windowSizeSamples);
    await Future.wait([
      for (var i = 0; i < _warmupRequestCount; i += 1)
        detect(pcm16KhzMono: warmup, sampleRateHz: model.sampleRateHz),
    ]);
  }

  @override
  Future<VadResult> detect({
    required Int16List pcm16KhzMono,
    required int sampleRateHz,
  }) async {
    _ensureSampleRate(sampleRateHz);

    final bytes = Uint8List.view(
      pcm16KhzMono.buffer,
      pcm16KhzMono.offsetInBytes,
      pcm16KhzMono.lengthInBytes,
    );
    final resultJson = await _request([
      'detect',
      sileroVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
      TransferableTypedData.fromList([bytes]),
    ]);

    return readVadResult(
      jsonDecode(resultJson) as Map<String, Object?>,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: pcm16KhzMono.length,
    );
  }

  /// Detect speech from native-memory PCM16 without copying the input in the
  /// Dart FFI wrapper.
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

    final resultJson = await _request([
      'detectPointer',
      sileroVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
      pcm16BytesPtr.address,
      pcm16ByteLength,
    ]);

    return readVadResult(
      jsonDecode(resultJson) as Map<String, Object?>,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: sampleLength,
    );
  }

  void _ensureSampleRate(int sampleRateHz) {
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Silero VAD ${model.version} expects ${model.sampleRateHz} Hz audio.',
      );
    }
  }
}

final class SileroVadWorker extends _SileroVadWorkerBase {
  SileroVadWorker._({
    required this._worker,
    required super.model,
    required super.options,
  });

  final DartEdgeIsolateWorker _worker;

  static Future<SileroVadWorker> spawn({
    SileroVadModel model = SileroVadModel.latest,
    SileroVadOptions options = const SileroVadOptions(),
    bool initialize = false,
  }) async {
    final worker = SileroVadWorker._(
      worker: await DartEdgeIsolateWorker.spawn(
        handler: _handleSileroVadWorkerRequest,
        debugName: 'SileroVadWorker',
      ),
      model: model,
      options: options,
    );
    if (initialize) {
      await worker.initialize();
    }
    return worker;
  }

  @override
  Future<String> _request(List<Object?> request) => _worker.request(request);

  Future<void> close() => _worker.close();
}

/// Pool of long-lived isolate-backed Silero VAD detectors.
///
/// Use this for repeated concurrent requests when a single [SileroVadWorker]
/// would serialize too much native-backed work through one isolate.
final class SileroVadWorkerPool extends _SileroVadWorkerBase {
  SileroVadWorkerPool._({
    required this._pool,
    required super.model,
    required super.options,
    required this.size,
  });

  final int size;

  final DartEdgeIsolateWorkerPool _pool;

  static Future<SileroVadWorkerPool> spawn({
    int size = 4,
    SileroVadModel model = SileroVadModel.latest,
    SileroVadOptions options = const SileroVadOptions(),
    bool initialize = false,
    DartEdgeIsolateWorkerPoolStrategy strategy =
        DartEdgeIsolateWorkerPoolStrategy.leastPending,
    int? maxPendingRequestsPerWorker,
    Duration? defaultTimeout,
  }) async {
    final pool = SileroVadWorkerPool._(
      pool: await DartEdgeIsolateWorkerPool.spawn(
        handler: _handleSileroVadWorkerRequest,
        debugName: 'SileroVadWorkerPool',
        size: size,
        strategy: strategy,
        maxPendingRequestsPerWorker: maxPendingRequestsPerWorker,
        defaultTimeout: defaultTimeout,
      ),
      model: model,
      options: options,
      size: size,
    );
    if (initialize) {
      await pool.initialize();
    }
    return pool;
  }

  @override
  int get _warmupRequestCount => size;

  @override
  Future<String> _request(List<Object?> request) => _pool.request(request);

  Future<void> close() => _pool.close();
}

Object? _handleSileroVadWorkerRequest(Object? request) {
  final values = request as List<Object?>;
  switch (values[0]) {
    case 'detect':
      final requestJson = values[1] as String;
      final transferable = values[2] as TransferableTypedData;
      final input = transferable.materialize().asUint8List();
      return DartEdgeVadNative.detectSilero(requestJson, input);
    case 'detectPointer':
      final requestJson = values[1] as String;
      final inputAddress = values[2] as int;
      final inputLength = values[3] as int;
      final inputPtr = inputAddress == 0
          ? nullptr
          : Pointer<Uint8>.fromAddress(inputAddress);
      return DartEdgeVadNative.detectSileroPointer(
        requestJson,
        inputPtr,
        inputLength,
      );
    default:
      throw StateError('Unknown Silero VAD worker command: ${values[0]}');
  }
}
