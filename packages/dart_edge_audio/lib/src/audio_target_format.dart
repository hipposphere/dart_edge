import 'audio_output_spec.dart';

/// Legacy WAV output selector.
///
/// New code should use [AudioOutputSpec], which also supports compressed
/// formats and their codec-specific settings.
enum AudioTargetFormat {
  wavPcm16,
  wavPcm24;

  int get bitDepth => switch (this) {
    AudioTargetFormat.wavPcm16 => 16,
    AudioTargetFormat.wavPcm24 => 24,
  };

  String get mimeType => 'audio/wav';

  String get wireValue => switch (this) {
    AudioTargetFormat.wavPcm16 => 'wavPcm16',
    AudioTargetFormat.wavPcm24 => 'wavPcm24',
  };

  static AudioTargetFormat fromWireValue(String value) => switch (value) {
    'wavPcm16' => AudioTargetFormat.wavPcm16,
    'wavPcm24' => AudioTargetFormat.wavPcm24,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported audio target format.',
    ),
  };

  AudioOutputSpec get output => switch (this) {
    AudioTargetFormat.wavPcm16 => const AudioOutputSpec.wavPcm16(),
    AudioTargetFormat.wavPcm24 => const AudioOutputSpec.wavPcm24(),
  };
}
