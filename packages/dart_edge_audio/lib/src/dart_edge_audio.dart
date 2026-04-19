import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_core/ffi.dart' as core_ffi;

import 'audio_bytes_conversion_request.dart';
import 'audio_bytes_conversion_result.dart';
import 'audio_channel_layout.dart';
import 'audio_file_conversion_request.dart';
import 'audio_file_conversion_result.dart';
import 'audio_metadata.dart';
import 'audio_target_format.dart';
import 'native/dart_edge_audio_native.dart';

/// Stateless facade for native-backed audio probing and conversion.
abstract final class DartEdgeAudio {
  static Future<AudioMetadata> probeFile(String path) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be empty.');
    }

    final resultJson = await Isolate.run(
      () => DartEdgeAudioNative.probeFile(path),
    );
    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  static Future<AudioMetadata> probeBytes(
    Uint8List bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
  }) async {
    _ensureBytes(bytes);

    final transferable = TransferableTypedData.fromList([bytes]);
    final resultJson = await Isolate.run(() {
      final materialized = transferable.materialize().asUint8List();
      return DartEdgeAudioNative.probeBytes(
        materialized,
        fileNameHint: fileNameHint,
        mimeTypeHint: mimeTypeHint,
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
  }) async {
    _ensureNativeBytes(bytes);

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
      );
    });

    return AudioMetadata.fromJson(_decodeJsonObject(resultJson));
  }

  static Future<AudioFileConversionResult> convertFile(
    AudioFileConversionRequest request,
  ) async {
    _ensureFileRequest(request);
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
}

Map<String, Object?> _decodeJsonObject(String input) {
  return jsonDecode(input) as Map<String, Object?>;
}
