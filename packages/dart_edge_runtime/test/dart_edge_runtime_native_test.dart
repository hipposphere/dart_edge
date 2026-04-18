import 'package:dart_edge_runtime/dart_edge_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('loads the bundled Rust runtime asset', () {
    expect(DartEdgeNative.abiVersion, 8);
    expect(DartEdgeNative.hasBundledRuntime, isTrue);
  });
}
