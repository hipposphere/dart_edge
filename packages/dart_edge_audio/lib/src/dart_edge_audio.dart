import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'audio_bytes_conversion_request.dart';
import 'audio_bytes_conversion_result.dart';
import 'audio_file_conversion_request.dart';
import 'audio_file_conversion_result.dart';
import 'audio_metadata.dart';
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
