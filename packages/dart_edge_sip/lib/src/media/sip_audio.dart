enum SipAudioEncoding { pcm16le }

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
}
