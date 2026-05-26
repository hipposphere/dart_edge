import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';
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
import 'native/dart_edge_audio_native.dart';

/// Long-lived isolate-backed audio probe/conversion worker.
///
/// Use this for latency-sensitive servers that want to pay isolate and native
/// audio initialization during startup instead of on the first real request.
final class DartEdgeAudioWorker {
  const DartEdgeAudioWorker._({required this._worker});

  final DartEdgeIsolateWorker _worker;

  static Future<DartEdgeAudioWorker> spawn({bool initialize = false}) async {
    final worker = DartEdgeAudioWorker._(
      worker: await DartEdgeIsolateWorker.spawn(
        handler: _handleAudioWorkerRequest,
        debugName: 'DartEdgeAudioWorker',
      ),
    );
    if (initialize) {
      await worker.initialize();
    }
    return worker;
  }

  Future<void> initialize() async {
    await probeBytes(
      _warmupWav16KhzMono,
      fileNameHint: 'audio-warmup.wav',
      mimeTypeHint: 'audio/wav',
      mode: AudioProbeMode.shallow,
    );
  }

  Future<AudioMetadata> probeFile(
    String path, {
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be empty.');
    }
    final resultJson = await _worker.request<String>([
      'probeFile',
      path,
      mode.wireValue,
    ]);
    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  Future<AudioMetadata> probeBytes(
    Uint8List bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureBytes(bytes);
    final resultJson = await _worker.request<String>([
      'probeBytes',
      TransferableTypedData.fromList([bytes]),
      fileNameHint,
      mimeTypeHint,
      mode.wireValue,
    ]);
    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  Future<AudioMetadata> probeNativeBytes(
    core_ffi.NativeBytes bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureNativeBytes(bytes);
    final resultJson = await _worker.request<String>([
      'probeNativeBytes',
      bytes.ptr.address,
      bytes.len,
      fileNameHint,
      mimeTypeHint,
      mode.wireValue,
    ]);
    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  Future<AudioFileConversionResult> convertFile(
    AudioFileConversionRequest request,
  ) async {
    _ensureFileRequest(request);
    final resultJson = await _worker.request<String>([
      'convertFile',
      jsonEncode(request.toJson()),
    ]);
    return AudioFileConversionResult.fromJson(_decodeJsonObject(resultJson));
  }

  Future<AudioBytesConversionResult> convertBytes(
    AudioBytesConversionRequest request,
  ) async {
    _ensureBytes(request.inputBytes);
    _ensurePositiveSampleRate(request.targetSampleRate);
    final payload = await _worker.request<Map<Object?, Object?>>([
      'convertBytes',
      jsonEncode(request.toJson()),
      TransferableTypedData.fromList([request.inputBytes]),
    ]);
    return _readBytesConversionResult(payload);
  }

  Future<AudioBytesConversionResult> convertNativeBytes({
    required core_ffi.NativeBytes bytes,
    required AudioTargetFormat targetFormat,
    int? targetSampleRate,
    AudioChannelLayout channelLayout = AudioChannelLayout.keepSource,
    String? fileNameHint,
    String? mimeTypeHint,
  }) async {
    _ensureNativeBytes(bytes);
    _ensurePositiveSampleRate(targetSampleRate);
    final payload = await _worker.request<Map<Object?, Object?>>([
      'convertNativeBytes',
      jsonEncode({
        'targetFormat': targetFormat.wireValue,
        'targetSampleRate': targetSampleRate,
        'channelLayout': channelLayout.wireValue,
        'fileNameHint': fileNameHint,
        'mimeTypeHint': mimeTypeHint,
      }),
      bytes.ptr.address,
      bytes.len,
    ]);
    return _readBytesConversionResult(payload);
  }

  Future<void> close() => _worker.close();
}

AudioBytesConversionResult _readBytesConversionResult(
  Map<Object?, Object?> payload,
) {
  return AudioBytesConversionResult.fromJson(
    _decodeJsonObject(payload['resultJson'] as String),
    bytes: (payload['bytes'] as TransferableTypedData)
        .materialize()
        .asUint8List(),
  );
}

Object? _handleAudioWorkerRequest(Object? request) {
  final values = request as List<Object?>;
  switch (values[0]) {
    case 'probeFile':
      return DartEdgeAudioNative.probeFile(
        values[1] as String,
        mode: AudioProbeMode.fromWireValue(values[2] as String),
      );
    case 'probeBytes':
      final transferable = values[1] as TransferableTypedData;
      final bytes = transferable.materialize().asUint8List();
      return DartEdgeAudioNative.probeBytes(
        bytes,
        fileNameHint: values[2] as String?,
        mimeTypeHint: values[3] as String?,
        mode: AudioProbeMode.fromWireValue(values[4] as String),
      );
    case 'probeNativeBytes':
      final bytesPtrAddress = values[1] as int;
      final bytesLength = values[2] as int;
      final bytesPtr = bytesPtrAddress == 0
          ? nullptr.cast<Uint8>()
          : Pointer<Uint8>.fromAddress(bytesPtrAddress);
      return DartEdgeAudioNative.probeRawBytes(
        bytesPtr,
        bytesLength,
        fileNameHint: values[3] as String?,
        mimeTypeHint: values[4] as String?,
        mode: AudioProbeMode.fromWireValue(values[5] as String),
      );
    case 'convertFile':
      return DartEdgeAudioNative.convertFile(values[1] as String);
    case 'convertBytes':
      final requestJson = values[1] as String;
      final transferable = values[2] as TransferableTypedData;
      final bytes = transferable.materialize().asUint8List();
      final result = DartEdgeAudioNative.convertBytes(requestJson, bytes);
      return <String, Object>{
        'resultJson': result.resultJson,
        'bytes': TransferableTypedData.fromList([result.bytes]),
      };
    case 'convertNativeBytes':
      final requestJson = values[1] as String;
      final bytesPtrAddress = values[2] as int;
      final bytesLength = values[3] as int;
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
    default:
      throw StateError('Unknown dart_edge_audio worker command: ${values[0]}');
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

void _ensureBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw ArgumentError.value(
      bytes,
      'bytes',
      'Audio byte input must not be empty.',
    );
  }
}

void _ensureNativeBytes(core_ffi.NativeBytes bytes) {
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

Map<String, Object?> _decodeJsonObject(String input) {
  return jsonDecode(input) as Map<String, Object?>;
}

final _warmupWav16KhzMono = Uint8List.fromList(const <int>[
  0x52, 0x49, 0x46, 0x46, 0x26, 0x00, 0x00, 0x00, // RIFF, size 38.
  0x57, 0x41, 0x56, 0x45, // WAVE.
  0x66, 0x6d, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, // fmt chunk.
  0x01, 0x00, // PCM.
  0x01, 0x00, // Mono.
  0x80, 0x3e, 0x00, 0x00, // 16 kHz.
  0x00, 0x7d, 0x00, 0x00, // Byte rate.
  0x02, 0x00, // Block align.
  0x10, 0x00, // Bits per sample.
  0x64, 0x61, 0x74, 0x61, 0x02, 0x00, 0x00, 0x00, // One silent sample.
  0x00, 0x00,
]);
