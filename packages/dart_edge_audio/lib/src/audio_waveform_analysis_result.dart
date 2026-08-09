import 'dart:typed_data';

import 'audio_metadata.dart';
import 'audio_waveform.dart';

/// Waveform and normalized timing metadata produced without WAV output bytes.
final class AudioWaveformAnalysisResult {
  const AudioWaveformAnalysisResult({
    required this.metadata,
    required this.waveform,
  });

  final AudioMetadata metadata;
  final AudioWaveform waveform;

  factory AudioWaveformAnalysisResult.fromJson(
    Map<String, Object?> json, {
    required Uint8List waveformBytes,
  }) {
    return AudioWaveformAnalysisResult(
      metadata: AudioMetadata.fromJson(
        json['metadata'] as Map<String, Object?>,
      ),
      waveform: AudioWaveform.fromJson(
        json['waveform'] as Map<String, Object?>,
        bytes: waveformBytes,
      ),
    );
  }
}
