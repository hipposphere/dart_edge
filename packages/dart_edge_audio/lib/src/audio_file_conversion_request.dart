import 'audio_channel_layout.dart';
import 'audio_output_spec.dart';
import 'audio_target_format.dart';

/// Request payload for converting an audio file on disk.
final class AudioFileConversionRequest {
  AudioFileConversionRequest({
    required this.inputPath,
    required this.outputPath,
    AudioOutputSpec? output,
    AudioTargetFormat? targetFormat,
    this.targetSampleRate,
    this.channelLayout = AudioChannelLayout.keepSource,
    this.overwriteExisting = false,
  }) : output = _resolveOutput(output, targetFormat);

  final String inputPath;
  final String outputPath;
  final AudioOutputSpec output;

  @Deprecated('Use output instead.')
  AudioTargetFormat get targetFormat => switch (output) {
    WavPcm16AudioOutputSpec() => AudioTargetFormat.wavPcm16,
    WavPcm24AudioOutputSpec() => AudioTargetFormat.wavPcm24,
    _ => throw StateError(
      'Compressed outputs do not have a legacy AudioTargetFormat.',
    ),
  };
  final int? targetSampleRate;
  final AudioChannelLayout channelLayout;
  final bool overwriteExisting;

  Map<String, Object?> toJson() {
    return {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'targetFormat': output.toJson(),
      'targetSampleRate': targetSampleRate,
      'channelLayout': channelLayout.wireValue,
      'overwriteExisting': overwriteExisting,
    };
  }
}

AudioOutputSpec _resolveOutput(
  AudioOutputSpec? output,
  AudioTargetFormat? targetFormat,
) {
  if (output != null && targetFormat != null) {
    throw ArgumentError('Only one of output and targetFormat may be provided.');
  }
  return AudioOutputSpec.resolve(output ?? targetFormat?.output);
}
