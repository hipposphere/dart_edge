import 'dart:typed_data';

import 'audio_metadata.dart';

/// Result of converting in-memory audio bytes.
final class AudioBytesConversionResult {
  const AudioBytesConversionResult({
    required this.bytes,
    required this.mimeType,
    required this.metadata,
  });

  final Uint8List bytes;
  final String mimeType;
  final AudioMetadata metadata;

  factory AudioBytesConversionResult.fromJson(
    Map<String, Object?> json, {
    required Uint8List bytes,
  }) {
    return AudioBytesConversionResult(
      bytes: bytes,
      mimeType: json['mimeType'] as String,
      metadata: AudioMetadata.fromJson(
        json['metadata'] as Map<String, Object?>,
      ),
    );
  }
}
