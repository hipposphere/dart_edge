/// Requested output channel arrangement for audio conversion.
enum AudioChannelLayout {
  keepSource,
  mono,
  stereo;

  String get wireValue => switch (this) {
    AudioChannelLayout.keepSource => 'keepSource',
    AudioChannelLayout.mono => 'mono',
    AudioChannelLayout.stereo => 'stereo',
  };

  static AudioChannelLayout fromWireValue(String value) => switch (value) {
    'keepSource' => AudioChannelLayout.keepSource,
    'mono' => AudioChannelLayout.mono,
    'stereo' => AudioChannelLayout.stereo,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported audio channel layout.',
    ),
  };
}
