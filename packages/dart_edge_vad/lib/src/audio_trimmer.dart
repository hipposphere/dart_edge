import 'dart:typed_data';

import 'vad_result.dart';
import 'wav_audio.dart';

/// Helpers for trimming audio payloads by VAD speech segments.
abstract final class AudioTrimmer {
  static Int16List trimPcm16BySegments(
    Int16List pcm16,
    List<VadSegment> segments,
  ) {
    final totalSamples = segments.fold<int>(
      0,
      (total, segment) => total + segment.lengthSamples,
    );
    final trimmed = Int16List(totalSamples);
    var offset = 0;
    for (final segment in segments) {
      final start = segment.startSample.clamp(0, pcm16.length);
      final end = segment.endSample.clamp(start, pcm16.length);
      final length = end - start;
      trimmed.setRange(offset, offset + length, pcm16, start);
      offset += length;
    }
    return offset == trimmed.length
        ? trimmed
        : Int16List.sublistView(trimmed, 0, offset);
  }

  static List<Int16List> splitPcm16BySegments(
    Int16List pcm16,
    List<VadSegment> segments,
  ) {
    return [for (final segment in segments) _pcm16ForSegment(pcm16, segment)];
  }

  static Uint8List trimWavBySegments(Uint8List wav, List<VadSegment> segments) {
    return WavAudio.parse(wav).trimBySegments(segments);
  }

  static List<Uint8List> splitWavBySegments(
    Uint8List wav,
    List<VadSegment> segments,
  ) {
    return WavAudio.parse(wav).splitBySegments(segments);
  }

  static Uint8List trimBySegments(Uint8List wav, List<VadSegment> segments) {
    return trimWavBySegments(wav, segments);
  }

  static Int16List _pcm16ForSegment(Int16List pcm16, VadSegment segment) {
    final start = segment.startSample.clamp(0, pcm16.length);
    final end = segment.endSample.clamp(start, pcm16.length);
    return Int16List.sublistView(pcm16, start, end);
  }
}
