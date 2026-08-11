import 'audio_waveform.dart';

void validateAudioWaveformSpec(AudioWaveformSpec? spec) {
  if (spec == null) return;
  if (spec.baseInterval.inMicroseconds < 1) {
    throw ArgumentError.value(
      spec.baseInterval,
      'waveform.baseInterval',
      'baseInterval must be at least one microsecond.',
    );
  }
  if (spec.levelFactors.isEmpty || spec.levelFactors.first != 1) {
    throw ArgumentError.value(
      spec.levelFactors,
      'waveform.levelFactors',
      'levelFactors must start with 1.',
    );
  }
  var previous = 0;
  for (final factor in spec.levelFactors) {
    if (factor <= previous) {
      throw ArgumentError.value(
        spec.levelFactors,
        'waveform.levelFactors',
        'levelFactors must be unique, positive, and increasing.',
      );
    }
    previous = factor;
  }
}
