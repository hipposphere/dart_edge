import 'dart:typed_data';

import 'vad_result.dart';

/// Voice activity detector contract.
abstract interface class Vad {
  Future<VadResult> detect({
    required Int16List pcm16KhzMono,
    required int sampleRateHz,
  });
}
