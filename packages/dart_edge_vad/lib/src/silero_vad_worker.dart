import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

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
final class SileroVadWorker implements Vad {
  SileroVadWorker._({
    required this._isolate,
    required this._sendPort,
    required ReceivePort receivePort,
    required this.model,
    required this.options,
  }) : _receivePort = receivePort {
    _subscription = receivePort.listen(_handleMessage);
  }

  final SileroVadModel model;

  final SileroVadOptions options;

  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  late final StreamSubscription<Object?> _subscription;
  final _pending = <int, Completer<String>>{};
  var _nextId = 0;
  var _closed = false;

  static Future<SileroVadWorker> spawn({
    SileroVadModel model = SileroVadModel.latest,
    SileroVadOptions options = const SileroVadOptions(),
    bool initialize = false,
  }) async {
    final readyPort = ReceivePort();
    final isolate = await Isolate.spawn(
      _sileroVadWorkerMain,
      readyPort.sendPort,
    );
    final sendPort = await readyPort.first as SendPort;
    readyPort.close();
    final receivePort = ReceivePort();
    sendPort.send(['listen', receivePort.sendPort]);

    final worker = SileroVadWorker._(
      isolate: isolate,
      sendPort: sendPort,
      receivePort: receivePort,
      model: model,
      options: options,
    );
    if (initialize) {
      await worker.initialize();
    }
    return worker;
  }

  /// Warm this worker's native Silero inference path before real requests.
  Future<void> initialize() async {
    await detect(
      pcm16KhzMono: Int16List(model.windowSizeSamples),
      sampleRateHz: model.sampleRateHz,
    );
  }

  @override
  Future<VadResult> detect({
    required Int16List pcm16KhzMono,
    required int sampleRateHz,
  }) async {
    if (_closed) {
      throw StateError('Silero VAD worker is closed.');
    }
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Silero VAD ${model.version} expects ${model.sampleRateHz} Hz audio.',
      );
    }

    final bytes = Uint8List.view(
      pcm16KhzMono.buffer,
      pcm16KhzMono.offsetInBytes,
      pcm16KhzMono.lengthInBytes,
    );
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _sendPort.send([
      'detect',
      id,
      sileroVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
      TransferableTypedData.fromList([bytes]),
    ]);

    final resultJson = await completer.future;
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
    if (_closed) {
      throw StateError('Silero VAD worker is closed.');
    }
    if (sampleRateHz != model.sampleRateHz) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'Silero VAD ${model.version} expects ${model.sampleRateHz} Hz audio.',
      );
    }
    RangeError.checkNotNegative(pcm16ByteLength, 'pcm16ByteLength');
    RangeError.checkNotNegative(sampleLength, 'sampleLength');
    if (pcm16ByteLength != sampleLength * 2) {
      throw ArgumentError.value(
        pcm16ByteLength,
        'pcm16ByteLength',
        'PCM16 byte length must be exactly sampleLength * 2.',
      );
    }

    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _sendPort.send([
      'detectPointer',
      id,
      sileroVadRequestJson(
        model: model,
        options: options,
        sampleRateHz: sampleRateHz,
      ),
      pcm16BytesPtr.address,
      pcm16ByteLength,
    ]);

    final resultJson = await completer.future;
    return readVadResult(
      jsonDecode(resultJson) as Map<String, Object?>,
      expectedSampleRateHz: sampleRateHz,
      expectedTotalSamples: sampleLength,
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _sendPort.send(['close']);
    await _subscription.cancel();
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Silero VAD worker is closed.'));
      }
    }
    _pending.clear();
  }

  void _handleMessage(Object? message) {
    final values = message as List<Object?>;
    final id = values[0] as int;
    final success = values[1] as bool;
    final payload = values[2] as String;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) {
      return;
    }
    if (success) {
      completer.complete(payload);
    } else {
      completer.completeError(StateError(payload));
    }
  }
}

void _sileroVadWorkerMain(SendPort readyPort) {
  final commandPort = ReceivePort();
  SendPort? responsePort;
  readyPort.send(commandPort.sendPort);

  commandPort.listen((message) {
    final values = message as List<Object?>;
    switch (values[0]) {
      case 'listen':
        responsePort = values[1] as SendPort;
      case 'close':
        commandPort.close();
      case 'detect':
        final id = values[1] as int;
        final requestJson = values[2] as String;
        final transferable = values[3] as TransferableTypedData;
        try {
          final input = transferable.materialize().asUint8List();
          final resultJson = DartEdgeVadNative.detectSilero(requestJson, input);
          responsePort?.send([id, true, resultJson]);
        } catch (error) {
          responsePort?.send([id, false, error.toString()]);
        }
      case 'detectPointer':
        final id = values[1] as int;
        final requestJson = values[2] as String;
        final inputAddress = values[3] as int;
        final inputLength = values[4] as int;
        try {
          final inputPtr = inputAddress == 0
              ? nullptr
              : Pointer<Uint8>.fromAddress(inputAddress);
          final resultJson = DartEdgeVadNative.detectSileroPointer(
            requestJson,
            inputPtr,
            inputLength,
          );
          responsePort?.send([id, true, resultJson]);
        } catch (error) {
          responsePort?.send([id, false, error.toString()]);
        }
    }
  });
}
