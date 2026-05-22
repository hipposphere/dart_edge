import 'dart:math' as math;

/// One inclusive-exclusive speech segment in sample offsets.
final class VadSegment {
  const VadSegment({
    required this.startSample,
    required this.endSample,
    required this.sampleRateHz,
  }) : assert(startSample >= 0),
       assert(endSample >= startSample),
       assert(sampleRateHz > 0);

  /// Inclusive start sample offset.
  final int startSample;

  /// Exclusive end sample offset.
  final int endSample;

  /// Sample rate used to interpret [startSample] and [endSample].
  final int sampleRateHz;

  int get lengthSamples => endSample - startSample;

  Duration get start => _durationForSamples(startSample, sampleRateHz);

  Duration get end => _durationForSamples(endSample, sampleRateHz);

  Duration get duration => _durationForSamples(lengthSamples, sampleRateHz);

  VadSegment clamp({required int totalSamples}) {
    final start = math.min(startSample, totalSamples);
    final end = math.min(math.max(endSample, start), totalSamples);
    return VadSegment(
      startSample: start,
      endSample: end,
      sampleRateHz: sampleRateHz,
    );
  }

  Map<String, Object> toJson() => {
    'startSample': startSample,
    'endSample': endSample,
    'sampleRateHz': sampleRateHz,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };

  @override
  String toString() =>
      'VadSegment(startSample: $startSample, endSample: $endSample, '
      'sampleRateHz: $sampleRateHz)';
}

/// Voice activity detection result for one audio buffer.
final class VadResult {
  const VadResult({
    required this.segments,
    required this.sampleRateHz,
    required this.totalSamples,
  }) : assert(sampleRateHz > 0),
       assert(totalSamples >= 0);

  final List<VadSegment> segments;
  final int sampleRateHz;
  final int totalSamples;

  bool get hasSpeech => segments.isNotEmpty;

  int get speechSamples =>
      segments.fold<int>(0, (total, segment) => total + segment.lengthSamples);

  Duration get duration => _durationForSamples(totalSamples, sampleRateHz);

  Duration get speechDuration =>
      _durationForSamples(speechSamples, sampleRateHz);

  double get speechRatio {
    if (totalSamples == 0) {
      return 0;
    }
    return speechSamples / totalSamples;
  }

  Map<String, Object> toJson() => {
    'sampleRateHz': sampleRateHz,
    'totalSamples': totalSamples,
    'hasSpeech': hasSpeech,
    'segments': segments.map((segment) => segment.toJson()).toList(),
  };
}

Duration _durationForSamples(int samples, int sampleRateHz) {
  return Duration(microseconds: (samples * 1000000 / sampleRateHz).round());
}
