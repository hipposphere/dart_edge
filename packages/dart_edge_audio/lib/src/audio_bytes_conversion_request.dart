import 'dart:typed_data';

import 'audio_channel_layout.dart';
import 'audio_target_format.dart';
import 'audio_waveform.dart';

/// Request payload for converting in-memory audio bytes.
final class AudioBytesConversionRequest {
  AudioBytesConversionRequest({
    required this.inputBytes,
    required this.targetFormat,
    this.targetSampleRate,
    this.channelLayout = AudioChannelLayout.keepSource,
    this.fileNameHint,
    this.mimeTypeHint,
    this.waveform,
  });

  final Uint8List inputBytes;
  final AudioTargetFormat targetFormat;
  final int? targetSampleRate;
  final AudioChannelLayout channelLayout;
  final String? fileNameHint;
  final String? mimeTypeHint;
  final AudioWaveformSpec? waveform;

  Map<String, Object?> toJson() {
    return {
      'targetFormat': targetFormat.wireValue,
      'targetSampleRate': targetSampleRate,
      'channelLayout': channelLayout.wireValue,
      'fileNameHint': fileNameHint,
      'mimeTypeHint': mimeTypeHint,
      'waveform': waveform?.toJson(),
    };
  }
}
