enum SipAudioEncoding { pcm16le }

final class SipMediaFormats {
  const SipMediaFormats({
    required this.capture,
    required this.playback,
    this.buffers = const SipMediaBufferConfig(),
  });

  const SipMediaFormats.symmetric(
    SipAudioFormat format, {
    this.buffers = const SipMediaBufferConfig(),
  }) : capture = format,
       playback = format;

  final SipAudioFormat capture;
  final SipAudioFormat playback;
  final SipMediaBufferConfig buffers;

  @override
  bool operator ==(Object other) {
    return other is SipMediaFormats &&
        other.capture == capture &&
        other.playback == playback &&
        other.buffers == buffers;
  }

  @override
  int get hashCode => Object.hash(capture, playback, buffers);

  @override
  String toString() {
    return 'SipMediaFormats(capture: $capture, playback: $playback)';
  }
}

final class SipMediaBufferConfig {
  const SipMediaBufferConfig({
    this.captureDuration = const Duration(seconds: 5),
    this.playbackDuration = const Duration(seconds: 2),
  });

  final Duration captureDuration;
  final Duration playbackDuration;

  @override
  bool operator ==(Object other) {
    return other is SipMediaBufferConfig &&
        other.captureDuration == captureDuration &&
        other.playbackDuration == playbackDuration;
  }

  @override
  int get hashCode => Object.hash(captureDuration, playbackDuration);
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

  int bytesFor(Duration duration) {
    return sampleRateHz *
        channels *
        bytesPerSample *
        duration.inMicroseconds ~/
        Duration.microsecondsPerSecond;
  }

  Duration durationForBytes(int byteCount) {
    final bytesPerSecond = sampleRateHz * channels * bytesPerSample;
    return Duration(
      microseconds:
          byteCount * Duration.microsecondsPerSecond ~/ bytesPerSecond,
    );
  }

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

final class SipAudioQueueDirectionStats {
  const SipAudioQueueDirectionStats({
    required this.queuedBytes,
    required this.capacityBytes,
    required this.overrunCount,
    required this.underrunCount,
    required this.droppedBytes,
    required this.queuedDuration,
    required this.capacityDuration,
  });

  final int queuedBytes;
  final int capacityBytes;
  final int overrunCount;
  final int underrunCount;
  final int droppedBytes;
  final Duration queuedDuration;
  final Duration capacityDuration;
}

final class SipAudioQueueStats {
  const SipAudioQueueStats({required this.capture, required this.playback});

  final SipAudioQueueDirectionStats capture;
  final SipAudioQueueDirectionStats playback;
}

final class SipMediaStats {
  const SipMediaStats({
    required this.codecId,
    required this.clockRateHz,
    required this.channels,
    required this.receivedPackets,
    required this.receivedPacketsLost,
    required this.sentPackets,
    required this.sentPacketsLost,
    required this.meanJitter,
    required this.meanRoundTrip,
    required this.jitterBufferLostFrames,
    required this.jitterBufferDiscardedFrames,
    required this.jitterBufferEmptyReads,
  });

  factory SipMediaStats.fromJson(Map<String, Object?> json) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return SipMediaStats(
      codecId: json['codecId'] as String? ?? '',
      clockRateHz: readInt('clockRateHz'),
      channels: readInt('channels'),
      receivedPackets: readInt('receivedPackets'),
      receivedPacketsLost: readInt('receivedPacketsLost'),
      sentPackets: readInt('sentPackets'),
      sentPacketsLost: readInt('sentPacketsLost'),
      meanJitter: Duration(microseconds: readInt('meanJitterUs')),
      meanRoundTrip: Duration(microseconds: readInt('meanRoundTripUs')),
      jitterBufferLostFrames: readInt('jitterBufferLostFrames'),
      jitterBufferDiscardedFrames: readInt('jitterBufferDiscardedFrames'),
      jitterBufferEmptyReads: readInt('jitterBufferEmptyReads'),
    );
  }

  final String codecId;
  final int clockRateHz;
  final int channels;
  final int receivedPackets;
  final int receivedPacketsLost;
  final int sentPackets;
  final int sentPacketsLost;
  final Duration meanJitter;
  final Duration meanRoundTrip;
  final int jitterBufferLostFrames;
  final int jitterBufferDiscardedFrames;
  final int jitterBufferEmptyReads;

  double get receivedPacketLossPercent {
    final total = receivedPackets + receivedPacketsLost;
    return total == 0 ? 0 : receivedPacketsLost * 100 / total;
  }
}
