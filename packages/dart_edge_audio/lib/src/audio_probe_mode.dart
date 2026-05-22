/// Controls how much work probing does before returning metadata.
enum AudioProbeMode {
  /// Read container and track metadata first, then decode fully only when the
  /// shallow probe cannot determine duration.
  adaptive,

  /// Read container and track metadata without decoding audio packets.
  shallow,

  /// Decode audio packets to validate decodability and compute exact duration.
  full;

  String get wireValue => switch (this) {
    AudioProbeMode.adaptive => 'adaptive',
    AudioProbeMode.shallow => 'shallow',
    AudioProbeMode.full => 'full',
  };

  static AudioProbeMode fromWireValue(String value) => switch (value) {
    'adaptive' => AudioProbeMode.adaptive,
    'shallow' => AudioProbeMode.shallow,
    'full' => AudioProbeMode.full,
    _ => throw ArgumentError.value(value, 'value', 'Unknown audio probe mode.'),
  };
}
