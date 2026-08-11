import 'package:dart_edge_audio/src/native/dart_edge_audio_native.dart';
import 'package:test/test.dart';

void main() {
  test('loads the bundled Rust audio asset', () {
    expect(DartEdgeAudioNative.abiVersion, 3);
    expect(DartEdgeAudioNative.hasBundledAsset, isTrue);
  });
}
