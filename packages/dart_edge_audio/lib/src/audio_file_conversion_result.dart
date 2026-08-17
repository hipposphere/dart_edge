import 'audio_metadata.dart';

/// Result of converting an audio file on disk.
final class AudioFileConversionResult {
  const AudioFileConversionResult({
    required this.outputPath,
    required this.mimeType,
    required this.metadata,
    this.fileExtension = '',
  });

  final String outputPath;
  final String mimeType;

  /// Recommended extension for the encoded output, without a leading dot.
  ///
  /// This is empty only for manually constructed legacy results.
  final String fileExtension;
  final AudioMetadata metadata;

  factory AudioFileConversionResult.fromJson(Map<String, Object?> json) {
    return AudioFileConversionResult(
      outputPath: json['outputPath'] as String,
      mimeType: json['mimeType'] as String,
      fileExtension: json['fileExtension'] as String? ?? '',
      metadata: AudioMetadata.fromJson(
        json['metadata'] as Map<String, Object?>,
      ),
    );
  }
}
