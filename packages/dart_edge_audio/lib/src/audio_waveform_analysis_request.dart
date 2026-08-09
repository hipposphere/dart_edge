import 'dart:typed_data';

import 'audio_channel_layout.dart';
import 'audio_waveform.dart';

/// Request for generating a waveform without returning converted audio bytes.
final class AudioWaveformAnalysisRequest {
  AudioWaveformAnalysisRequest({
    required this.inputBytes,
    required this.waveform,
    this.targetSampleRate,
    this.channelLayout = AudioChannelLayout.keepSource,
    this.fileNameHint,
    this.mimeTypeHint,
  });

  final Uint8List inputBytes;
  final AudioWaveformSpec waveform;
  final int? targetSampleRate;
  final AudioChannelLayout channelLayout;
  final String? fileNameHint;
  final String? mimeTypeHint;

  Map<String, Object?> toJson() => {
    'targetFormat': 'wavPcm16',
    'targetSampleRate': targetSampleRate,
    'channelLayout': channelLayout.wireValue,
    'fileNameHint': fileNameHint,
    'mimeTypeHint': mimeTypeHint,
    'waveform': waveform.toJson(),
    'waveformOnly': true,
  };
}
