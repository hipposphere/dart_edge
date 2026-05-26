import 'dart:typed_data';

import 'package:dart_edge_vad/dart_edge_vad.dart';

Future<void> main() async {
  final pcm = Int16List(16000);
  final wav = Uint8List(44);

  final vad = NativeVad();
  await vad.initialize();
  final result = await vad.detect(pcm16KhzMono: pcm, sampleRateHz: 16000);

  if (result.hasSpeech) {
    final trimmed = AudioTrimmer.trimBySegments(wav, result.segments);
    print('Trimmed ${trimmed.length} bytes');
  }

  await vad.close();
}
