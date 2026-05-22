import 'dart:convert';
import 'dart:typed_data';

import 'vad_result.dart';

/// Parsed PCM WAV audio.
final class WavAudio {
  const WavAudio._({
    required this.bytes,
    required this.sampleRateHz,
    required this.channels,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
    required this.blockAlign,
  });

  final Uint8List bytes;
  final int sampleRateHz;
  final int channels;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;
  final int blockAlign;

  int get sampleCount => dataLength ~/ blockAlign;

  static WavAudio parse(Uint8List bytes) {
    if (bytes.length < 44 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE') {
      throw FormatException('Expected RIFF/WAVE audio.', bytes);
    }

    var offset = 12;
    int? audioFormat;
    int? channels;
    int? sampleRateHz;
    int? bitsPerSample;
    int? blockAlign;
    int? dataOffset;
    int? dataLength;
    final view = ByteData.sublistView(bytes);

    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, 4);
      final chunkSize = view.getUint32(offset + 4, Endian.little);
      final payloadOffset = offset + 8;
      if (payloadOffset + chunkSize > bytes.length) {
        throw FormatException('WAV chunk extends past end of file.', bytes);
      }

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) {
          throw FormatException('WAV fmt chunk is too small.', bytes);
        }
        audioFormat = view.getUint16(payloadOffset, Endian.little);
        channels = view.getUint16(payloadOffset + 2, Endian.little);
        sampleRateHz = view.getUint32(payloadOffset + 4, Endian.little);
        blockAlign = view.getUint16(payloadOffset + 12, Endian.little);
        bitsPerSample = view.getUint16(payloadOffset + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = payloadOffset;
        dataLength = chunkSize;
      }

      offset = payloadOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat != 1) {
      throw FormatException('Only PCM WAV audio is supported.', bytes);
    }
    if (channels == null ||
        sampleRateHz == null ||
        bitsPerSample == null ||
        blockAlign == null ||
        dataOffset == null ||
        dataLength == null) {
      throw FormatException('WAV audio is missing fmt or data chunks.', bytes);
    }
    if (bitsPerSample != 16) {
      throw FormatException('Only 16-bit PCM WAV audio is supported.', bytes);
    }

    return WavAudio._(
      bytes: bytes,
      sampleRateHz: sampleRateHz,
      channels: channels,
      bitsPerSample: bitsPerSample,
      dataOffset: dataOffset,
      dataLength: dataLength,
      blockAlign: blockAlign,
    );
  }

  Uint8List trimBySegments(List<VadSegment> segments) {
    final data = BytesBuilder(copy: false);
    for (final segment in segments) {
      data.add(_pcmDataForSegment(segment));
    }

    return _writePcmWav(
      pcmData: data.takeBytes(),
      sampleRateHz: sampleRateHz,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
  }

  List<Uint8List> splitBySegments(List<VadSegment> segments) {
    return [
      for (final segment in segments)
        _writePcmWav(
          pcmData: _pcmDataForSegment(segment),
          sampleRateHz: sampleRateHz,
          channels: channels,
          bitsPerSample: bitsPerSample,
        ),
    ];
  }

  Uint8List _pcmDataForSegment(VadSegment segment) {
    if (segment.sampleRateHz != sampleRateHz) {
      throw ArgumentError.value(
        segment.sampleRateHz,
        'segments',
        'Segment sample rate must match WAV sample rate $sampleRateHz.',
      );
    }
    final clamped = segment.clamp(totalSamples: sampleCount);
    final startByte = dataOffset + clamped.startSample * blockAlign;
    final endByte = dataOffset + clamped.endSample * blockAlign;
    return Uint8List.sublistView(bytes, startByte, endByte);
  }
}

Uint8List _writePcmWav({
  required Uint8List pcmData,
  required int sampleRateHz,
  required int channels,
  required int bitsPerSample,
}) {
  final blockAlign = channels * bitsPerSample ~/ 8;
  final byteRate = sampleRateHz * blockAlign;
  final totalLength = 44 + pcmData.length;
  final bytes = Uint8List(totalLength);
  final view = ByteData.sublistView(bytes);

  _writeAscii(bytes, 0, 'RIFF');
  view.setUint32(4, totalLength - 8, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRateHz, Endian.little);
  view.setUint32(28, byteRate, Endian.little);
  view.setUint16(32, blockAlign, Endian.little);
  view.setUint16(34, bitsPerSample, Endian.little);
  _writeAscii(bytes, 36, 'data');
  view.setUint32(40, pcmData.length, Endian.little);
  bytes.setRange(44, totalLength, pcmData);
  return bytes;
}

String _ascii(Uint8List bytes, int offset, int length) {
  return ascii.decode(Uint8List.sublistView(bytes, offset, offset + length));
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  bytes.setRange(offset, offset + value.length, ascii.encode(value));
}
