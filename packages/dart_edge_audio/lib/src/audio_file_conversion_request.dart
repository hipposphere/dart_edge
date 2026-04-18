import 'audio_channel_layout.dart';
import 'audio_target_format.dart';

/// Request payload for converting an audio file on disk.
final class AudioFileConversionRequest {
  const AudioFileConversionRequest({
    required this.inputPath,
    required this.outputPath,
    required this.targetFormat,
    this.targetSampleRate,
    this.channelLayout = AudioChannelLayout.keepSource,
    this.overwriteExisting = false,
  });

  final String inputPath;
  final String outputPath;
  final AudioTargetFormat targetFormat;
  final int? targetSampleRate;
  final AudioChannelLayout channelLayout;
  final bool overwriteExisting;

  Map<String, Object?> toJson() {
    return {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'targetFormat': targetFormat.wireValue,
      'targetSampleRate': targetSampleRate,
      'channelLayout': channelLayout.wireValue,
      'overwriteExisting': overwriteExisting,
    };
  }
}
