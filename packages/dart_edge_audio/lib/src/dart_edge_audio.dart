import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;

import 'audio_bytes_conversion_request.dart';
import 'audio_bytes_conversion_result.dart';
import 'audio_channel_layout.dart';
import 'audio_file_conversion_request.dart';
import 'audio_file_conversion_result.dart';
import 'audio_metadata.dart';
import 'audio_probe_mode.dart';
import 'audio_target_format.dart';
import 'dart_edge_audio_worker.dart';
import 'native/dart_edge_audio_native.dart';

/// Stateless facade for native-backed audio probing and conversion.
abstract final class DartEdgeAudio {
  static DartEdgeAudioWorker? _sharedWorker;
  static Future<DartEdgeAudioWorker>? _sharedWorkerFuture;

  /// Starts and warms a shared worker used by the static facade methods.
  ///
  /// Await this during server startup to move native audio initialization and
  /// isolate startup out of the first real request.
  static Future<void> initialize() async {
    await _ensureSharedWorker();
  }

  /// Closes the shared worker created by [initialize].
  static Future<void> close() async {
    final worker = _sharedWorker;
    final workerFuture = _sharedWorkerFuture;
    _sharedWorker = null;
    _sharedWorkerFuture = null;
    if (worker != null) {
      await worker.close();
      return;
    }
    final pendingWorker = await workerFuture;
    await pendingWorker?.close();
  }

  static Future<AudioMetadata> probeFile(
    String path, {
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be empty.');
    }
    final worker = _sharedWorker;
    if (worker != null) {
      return worker.probeFile(path, mode: mode);
    }

    final resultJson = await Isolate.run(
      () => DartEdgeAudioNative.probeFile(path, mode: mode),
    );
    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  static Future<AudioMetadata> probeBytes(
    Uint8List bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureBytes(bytes);
    final worker = _sharedWorker;
    if (worker != null) {
      return worker.probeBytes(
        bytes,
        fileNameHint: fileNameHint,
        mimeTypeHint: mimeTypeHint,
        mode: mode,
      );
    }

    final transferable = TransferableTypedData.fromList([bytes]);
    final resultJson = await Isolate.run(() {
      final materialized = transferable.materialize().asUint8List();
      return DartEdgeAudioNative.probeBytes(
        materialized,
        fileNameHint: fileNameHint,
        mimeTypeHint: mimeTypeHint,
        mode: mode,
      );
    });

    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  /// Probes borrowed native audio bytes without first copying them into
  /// Dart-managed memory.
  ///
  /// The caller must keep [bytes] alive for the full duration of this call.
  /// This is intended for request-scoped native bodies coming from other Dart
  /// Edge runtime packages.
  static Future<AudioMetadata> probeNativeBytes(
    core_ffi.NativeBytes bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureNativeBytes(bytes);
    final worker = _sharedWorker;
    if (worker != null) {
      return worker.probeNativeBytes(
        bytes,
        fileNameHint: fileNameHint,
        mimeTypeHint: mimeTypeHint,
        mode: mode,
      );
    }

    final bytesPtrAddress = bytes.ptr.address;
    final bytesLength = bytes.len;
    final resultJson = await Isolate.run(() {
      final bytesPtr = bytesPtrAddress == 0
          ? nullptr.cast<Uint8>()
          : Pointer<Uint8>.fromAddress(bytesPtrAddress);
      return DartEdgeAudioNative.probeRawBytes(
        bytesPtr,
        bytesLength,
        fileNameHint: fileNameHint,
        mimeTypeHint: mimeTypeHint,
        mode: mode,
      );
    });

    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  static Future<AudioFileConversionResult> convertFile(
    AudioFileConversionRequest request,
  ) async {
    _ensureFileRequest(request);
    final worker = _sharedWorker;
    if (worker != null) {
      return worker.convertFile(request);
    }
    final requestJson = jsonEncode(request.toJson());

    final resultJson = await Isolate.run(
      () => DartEdgeAudioNative.convertFile(requestJson),
    );
    return AudioFileConversionResult.fromJson(_decodeJsonObject(resultJson));
  }

  static Future<AudioBytesConversionResult> convertBytes(
    AudioBytesConversionRequest request,
  ) async {
    _ensureBytes(request.inputBytes);
    _ensurePositiveSampleRate(request.targetSampleRate);
    final worker = _sharedWorker;
    if (worker != null) {
      return worker.convertBytes(request);
    }

    final requestJson = jsonEncode(request.toJson());
    final transferable = TransferableTypedData.fromList([request.inputBytes]);

    final payload = await Isolate.run(() {
      final materialized = transferable.materialize().asUint8List();
      final result = DartEdgeAudioNative.convertBytes(
        requestJson,
        materialized,
      );
      return <String, Object>{
        'resultJson': result.resultJson,
        'bytes': TransferableTypedData.fromList([result.bytes]),
      };
    });

    return AudioBytesConversionResult.fromJson(
      _decodeJsonObject(payload['resultJson'] as String),
      bytes: (payload['bytes'] as TransferableTypedData)
          .materialize()
          .asUint8List(),
    );
  }

  /// Converts borrowed native audio bytes without first copying them into
  /// Dart-managed memory.
  ///
  /// The caller must keep [bytes] alive for the full duration of this call.
  /// This is intended for request-scoped native bodies coming from other Dart
  /// Edge runtime packages.
  static Future<AudioBytesConversionResult> convertNativeBytes({
    required core_ffi.NativeBytes bytes,
    required AudioTargetFormat targetFormat,
    int? targetSampleRate,
    AudioChannelLayout channelLayout = AudioChannelLayout.keepSource,
    String? fileNameHint,
    String? mimeTypeHint,
  }) async {
    _ensureNativeBytes(bytes);
    _ensurePositiveSampleRate(targetSampleRate);
    final worker = _sharedWorker;
    if (worker != null) {
      return worker.convertNativeBytes(
        bytes: bytes,
        targetFormat: targetFormat,
        targetSampleRate: targetSampleRate,
        channelLayout: channelLayout,
        fileNameHint: fileNameHint,
        mimeTypeHint: mimeTypeHint,
      );
    }

    final requestJson = jsonEncode({
      'targetFormat': targetFormat.wireValue,
      'targetSampleRate': targetSampleRate,
      'channelLayout': channelLayout.wireValue,
      'fileNameHint': fileNameHint,
      'mimeTypeHint': mimeTypeHint,
    });
    final bytesPtrAddress = bytes.ptr.address;
    final bytesLength = bytes.len;

    final payload = await Isolate.run(() {
      final bytesPtr = bytesPtrAddress == 0
          ? nullptr.cast<Uint8>()
          : Pointer<Uint8>.fromAddress(bytesPtrAddress);
      final result = DartEdgeAudioNative.convertRawBytes(
        requestJson,
        bytesPtr,
        bytesLength,
      );
      return <String, Object>{
        'resultJson': result.resultJson,
        'bytes': TransferableTypedData.fromList([result.bytes]),
      };
    });

    return AudioBytesConversionResult.fromJson(
      _decodeJsonObject(payload['resultJson'] as String),
      bytes: (payload['bytes'] as TransferableTypedData)
          .materialize()
          .asUint8List(),
    );
  }

  static void _ensureFileRequest(AudioFileConversionRequest request) {
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

  static void _ensureBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Audio byte input must not be empty.',
      );
    }
  }

  static void _ensureNativeBytes(core_ffi.NativeBytes bytes) {
    if (bytes.ptr == nullptr || bytes.len <= 0) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Audio byte input must not be empty.',
      );
    }
  }

  static void _ensurePositiveSampleRate(int? sampleRate) {
    if (sampleRate case final sampleRate? when sampleRate < 1) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'sampleRate must be at least 1.',
      );
    }
  }

  static Future<DartEdgeAudioWorker> _ensureSharedWorker() {
    final worker = _sharedWorker;
    if (worker != null) {
      return Future.value(worker);
    }
    return _sharedWorkerFuture ??= DartEdgeAudioWorker.spawn(initialize: true)
        .then(
          (worker) {
            _sharedWorker = worker;
            _sharedWorkerFuture = null;
            return worker;
          },
          onError: (Object error, StackTrace stackTrace) {
            _sharedWorkerFuture = null;
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
  }
}

Map<String, Object?> _decodeJsonObject(String input) {
  return jsonDecode(input) as Map<String, Object?>;
}
