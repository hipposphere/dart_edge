import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('exposes a configurable call state transition timeout', () {
    final sip = DartEdgeSip(
      config: const SipServerConfig(),
      callStateTransitionTimeout: const Duration(seconds: 5),
    );

    expect(sip.callStateTransitionTimeout, const Duration(seconds: 5));
  });

  test('rejects a non-positive call state transition timeout', () {
    expect(
      () => DartEdgeSip(
        config: const SipServerConfig(),
        callStateTransitionTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
