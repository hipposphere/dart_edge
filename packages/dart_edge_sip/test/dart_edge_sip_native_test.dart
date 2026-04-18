import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('loads the bundled dart_edge_sip native asset', () {
    expect(DartEdgeSip.nativeAbiVersion, 1);
  });

  test(
    'runtime starts, originates a call, and emits lifecycle events',
    () async {
      final sip = DartEdgeSip(
        config: const SipServerConfig(
          engine: PjsipEngineConfig(maxCalls: 4, maxConferencePorts: 32),
          transports: [SipTransportBinding.udp(host: '127.0.0.1', port: 5160)],
          realms: [
            SipRealmConfig(domain: 'pbx.example.com', realm: 'pbx.example.com'),
          ],
        trunks: [
          SipTrunkConfig(
            id: 'carrier-a',
            direction: SipTrunkDirection.bidirectional,
            serverUri: 'sip:example.com',
          ),
        ],
      ),
      );
      addTearDown(sip.dispose);

      await sip.start();

      final inviteEventFuture = sip.callEvents.first;
      final call = await sip.originateCall(
      const SipOutboundCallRequest(
        trunkId: 'carrier-a',
        fromUri: 'sip:1000@pbx.example.com',
        toUri: 'sip:2000@example.com',
      ),
      );
      final inviteEvent = await inviteEventFuture.timeout(
        const Duration(seconds: 2),
      );
      expect(inviteEvent.callId, call.id);
      expect(inviteEvent.state, SipCallState.inviting);

      final hangupEventFuture = sip.callEvents.firstWhere(
        (event) => event.state == SipCallState.terminated,
      );
      await call.hangup();
      final hangupEvent = await hangupEventFuture.timeout(
        const Duration(seconds: 2),
      );
      expect(hangupEvent.callId, call.id);
    },
  );
}
