import 'dart:math' as math;
import 'dart:typed_data';

Uint8List buildStartupJingle(Duration duration) {
  const sampleRateHz = 16000;
  const frameFadeSamples = sampleRateHz ~/ 100;
  const amplitude = 0.20 * 32767;
  const notes = <double>[523.25, 659.25, 783.99, 659.25, 587.33, 739.99];
  final sampleCount = sampleRateHz * duration.inMilliseconds ~/ 1000;
  final output = Uint8List(sampleCount * 2);
  final view = ByteData.sublistView(output);

  for (var index = 0; index < sampleCount; index += 1) {
    final seconds = index / sampleRateHz;
    final noteIndex = ((seconds * 4).floor()) % notes.length;
    final frequency = notes[noteIndex];
    final fadeIn = math.min(1.0, index / frameFadeSamples);
    final fadeOut = math.min(1.0, (sampleCount - index - 1) / frameFadeSamples);
    final envelope = math.min(fadeIn, fadeOut);
    final carrier = math.sin(2 * math.pi * frequency * seconds);
    final overtone = 0.18 * math.sin(2 * math.pi * frequency * 2 * seconds);
    final sample = ((carrier + overtone) * amplitude * envelope).round();
    view.setInt16(index * 2, sample.clamp(-32768, 32767), Endian.little);
  }

  return output;
}

int? audioRateFromMimeType(String mimeType) {
  final match = RegExp(r'rate=(\d+)').firstMatch(mimeType);
  return match == null ? null : int.tryParse(match.group(1)!);
}

final class Pcm24kTo16kDownsampler {
  final List<int> _pending = <int>[];

  Uint8List convert(Uint8List input) {
    if (input.isEmpty && _pending.isEmpty) {
      return Uint8List(0);
    }

    final combined = Uint8List(_pending.length + input.length)
      ..setAll(0, _pending)
      ..setAll(_pending.length, input);
    final evenLength = combined.length - (combined.length % 2);
    final processLength = (evenLength ~/ 6) * 6;
    if (processLength == 0) {
      _pending
        ..clear()
        ..addAll(combined);
      return Uint8List(0);
    }

    final output = Uint8List((processLength ~/ 6) * 4);
    final inputView = ByteData.sublistView(combined, 0, processLength);
    final outputView = ByteData.sublistView(output);

    var outputOffset = 0;
    for (var inputOffset = 0; inputOffset < processLength; inputOffset += 6) {
      final first = inputView.getInt16(inputOffset, Endian.little);
      final second = inputView.getInt16(inputOffset + 2, Endian.little);
      final third = inputView.getInt16(inputOffset + 4, Endian.little);

      outputView.setInt16(outputOffset, first, Endian.little);
      outputOffset += 2;
      outputView.setInt16(
        outputOffset,
        ((second + third) ~/ 2).clamp(-32768, 32767),
        Endian.little,
      );
      outputOffset += 2;
    }

    _pending
      ..clear()
      ..addAll(combined.sublist(processLength));
    return output;
  }
}
