import 'dart:typed_data';

import 'audio_channel_layout.dart';
import 'audio_output_spec.dart';
import 'audio_target_format.dart';
import 'audio_waveform.dart';

/// Request payload for converting in-memory audio bytes.
final class AudioBytesConversionRequest {
  AudioBytesConversionRequest({
    required this.inputBytes,
    AudioOutputSpec? output,
    AudioTargetFormat? targetFormat,
    this.targetSampleRate,
    this.channelLayout = AudioChannelLayout.keepSource,
    this.fileNameHint,
    this.mimeTypeHint,
    this.waveform,
  }) : output = _resolveOutput(output, targetFormat);

  final Uint8List inputBytes;
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
  final String? fileNameHint;
  final String? mimeTypeHint;
  final AudioWaveformSpec? waveform;

  Map<String, Object?> toJson() {
    return {
      'targetFormat': output.toJson(),
      'targetSampleRate': targetSampleRate,
      'channelLayout': channelLayout.wireValue,
      'fileNameHint': fileNameHint,
      'mimeTypeHint': mimeTypeHint,
      'waveform': waveform?.toJson(),
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
