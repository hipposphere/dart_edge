enum SipAudioEncoding { pcm16le }

final class SipMediaFormats {
  const SipMediaFormats({required this.capture, required this.playback});

  const SipMediaFormats.symmetric(SipAudioFormat format)
    : capture = format,
      playback = format;

  final SipAudioFormat capture;
  final SipAudioFormat playback;

  @override
  bool operator ==(Object other) {
    return other is SipMediaFormats &&
        other.capture == capture &&
        other.playback == playback;
  }

  @override
  int get hashCode => Object.hash(capture, playback);

  @override
  String toString() {
    return 'SipMediaFormats(capture: $capture, playback: $playback)';
  }
}

final class SipAudioFormat {
  const SipAudioFormat({
    this.encoding = SipAudioEncoding.pcm16le,
    required this.sampleRateHz,
    this.channels = 1,
    this.frameDurationMs = 20,
  });

  const SipAudioFormat.voiceAssistant()
    : this(sampleRateHz: 16000, channels: 1, frameDurationMs: 20);

  final SipAudioEncoding encoding;
  final int sampleRateHz;
  final int channels;
  final int frameDurationMs;

  int get bytesPerSample => switch (encoding) {
    SipAudioEncoding.pcm16le => 2,
  };

  int get samplesPerFrame => sampleRateHz * frameDurationMs ~/ 1000;

  int get bytesPerFrame => samplesPerFrame * channels * bytesPerSample;

  @override
  bool operator ==(Object other) {
    return other is SipAudioFormat &&
        other.encoding == encoding &&
        other.sampleRateHz == sampleRateHz &&
        other.channels == channels &&
        other.frameDurationMs == frameDurationMs;
  }

  @override
  int get hashCode =>
      Object.hash(encoding, sampleRateHz, channels, frameDurationMs);

  @override
  String toString() {
    return 'SipAudioFormat('
        'encoding: $encoding, '
        'sampleRateHz: $sampleRateHz, '
        'channels: $channels, '
        'frameDurationMs: $frameDurationMs)';
  }
}
