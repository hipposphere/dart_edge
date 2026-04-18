/// Decoded metadata describing an audio asset or conversion output.
final class AudioMetadata {
  const AudioMetadata({
    required this.duration,
    required this.container,
    required this.codec,
    required this.sampleRate,
    required this.channelCount,
    required this.bitRate,
    required this.bitDepth,
    this.tags = const <String, String>{},
  });

  final Duration duration;
  final String? container;
  final String? codec;
  final int? sampleRate;
  final int? channelCount;
  final int? bitRate;
  final int? bitDepth;
  final Map<String, String> tags;

  factory AudioMetadata.fromJson(Map<String, Object?> json) {
    final tags = json['tags'] as Map<Object?, Object?>? ?? const {};
    return AudioMetadata(
      duration: Duration(microseconds: json['durationMicros'] as int? ?? 0),
      container: json['container'] as String?,
      codec: json['codec'] as String?,
      sampleRate: json['sampleRate'] as int?,
      channelCount: json['channelCount'] as int?,
      bitRate: json['bitRate'] as int?,
      bitDepth: json['bitDepth'] as int?,
      tags: Map.unmodifiable({
        for (final entry in tags.entries)
          entry.key.toString(): entry.value.toString(),
      }),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'durationMicros': duration.inMicroseconds,
      'container': container,
      'codec': codec,
      'sampleRate': sampleRate,
      'channelCount': channelCount,
      'bitRate': bitRate,
      'bitDepth': bitDepth,
      'tags': tags,
    };
  }
}
