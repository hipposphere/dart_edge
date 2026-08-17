/// Describes the encoded container produced by an audio conversion.
sealed class AudioOutputSpec {
  const AudioOutputSpec();

  const factory AudioOutputSpec.wavPcm16() = WavPcm16AudioOutputSpec;

  const factory AudioOutputSpec.wavPcm24() = WavPcm24AudioOutputSpec;

  const factory AudioOutputSpec.m4aAacLc({int bitRate}) =
      M4aAacLcAudioOutputSpec;

  const factory AudioOutputSpec.flac({int compressionLevel}) =
      FlacAudioOutputSpec;

  String get format;
  String get mimeType;
  String get fileExtension;
  String get container;
  String get codec;

  /// PCM bit depth when the encoded format preserves one explicitly.
  int? get bitDepth;

  Map<String, Object?> toJson();

  void validate();

  static AudioOutputSpec resolve(
    AudioOutputSpec? output, {
    AudioOutputSpec fallback = const AudioOutputSpec.wavPcm16(),
  }) {
    final resolved = output ?? fallback;
    resolved.validate();
    return resolved;
  }
}

final class WavPcm16AudioOutputSpec extends AudioOutputSpec {
  const WavPcm16AudioOutputSpec();

  @override
  String get format => 'wavPcm16';

  @override
  String get mimeType => 'audio/wav';

  @override
  String get fileExtension => 'wav';

  @override
  String get container => 'wav';

  @override
  String get codec => 'pcm_s16le';

  @override
  int get bitDepth => 16;

  @override
  Map<String, Object?> toJson() => {'format': format};

  @override
  void validate() {}
}

final class WavPcm24AudioOutputSpec extends AudioOutputSpec {
  const WavPcm24AudioOutputSpec();

  @override
  String get format => 'wavPcm24';

  @override
  String get mimeType => 'audio/wav';

  @override
  String get fileExtension => 'wav';

  @override
  String get container => 'wav';

  @override
  String get codec => 'pcm_s24le';

  @override
  int get bitDepth => 24;

  @override
  Map<String, Object?> toJson() => {'format': format};

  @override
  void validate() {}
}

/// MPEG-4 AAC Low Complexity in an M4A container.
final class M4aAacLcAudioOutputSpec extends AudioOutputSpec {
  const M4aAacLcAudioOutputSpec({this.bitRate = 48000});

  /// Target average bitrate in bits per second.
  final int bitRate;

  @override
  String get format => 'm4aAacLc';

  @override
  String get mimeType => 'audio/mp4';

  @override
  String get fileExtension => 'm4a';

  @override
  String get container => 'mp4';

  @override
  String get codec => 'aac';

  @override
  int? get bitDepth => null;

  @override
  Map<String, Object?> toJson() => {'format': format, 'bitRate': bitRate};

  @override
  void validate() {
    RangeError.checkValueInInterval(bitRate, 8000, 512000, 'bitRate');
  }
}

/// Lossless FLAC output.
final class FlacAudioOutputSpec extends AudioOutputSpec {
  const FlacAudioOutputSpec({this.compressionLevel = 5});

  final int compressionLevel;

  @override
  String get format => 'flac';

  @override
  String get mimeType => 'audio/flac';

  @override
  String get fileExtension => 'flac';

  @override
  String get container => 'flac';

  @override
  String get codec => 'flac';

  @override
  int get bitDepth => 16;

  @override
  Map<String, Object?> toJson() => {
    'format': format,
    'compressionLevel': compressionLevel,
  };

  @override
  void validate() {
    RangeError.checkValueInInterval(compressionLevel, 0, 8, 'compressionLevel');
  }
}
