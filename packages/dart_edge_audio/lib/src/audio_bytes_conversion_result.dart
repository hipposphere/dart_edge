import 'dart:typed_data';

import 'audio_metadata.dart';
import 'audio_waveform.dart';

/// Result of converting in-memory audio bytes.
final class AudioBytesConversionResult {
  const AudioBytesConversionResult({
    required this.bytes,
    required this.mimeType,
    required this.metadata,
    this.waveform,
  });

  final Uint8List bytes;
  final String mimeType;
  final AudioMetadata metadata;
  final AudioWaveform? waveform;

  factory AudioBytesConversionResult.fromJson(
    Map<String, Object?> json, {
    required Uint8List bytes,
    Uint8List? waveformBytes,
  }) {
    return AudioBytesConversionResult(
      bytes: bytes,
      mimeType: json['mimeType'] as String,
      metadata: AudioMetadata.fromJson(
        json['metadata'] as Map<String, Object?>,
      ),
      waveform: switch (json['waveform']) {
        final Map<String, Object?> waveform when waveformBytes != null =>
          AudioWaveform.fromJson(waveform, bytes: waveformBytes),
        _ => null,
      },
    );
  }
}
