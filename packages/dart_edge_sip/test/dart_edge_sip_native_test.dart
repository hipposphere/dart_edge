import 'dart:async';

import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('loads the bundled dart_edge_sip native asset', () {
    expect(DartEdgeSip.nativeAbiVersion, 3);
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
      expect(await sip.registeredEndpoints(), isEmpty);

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

  test('attaches a media app session to a call', () async {
    final runSession = Completer<SipMediaAppSession>();
    final sip = DartEdgeSip(
      config: const SipServerConfig(
        engine: PjsipEngineConfig(maxCalls: 4, maxConferencePorts: 32),
        transports: [SipTransportBinding.udp(host: '127.0.0.1', port: 5161)],
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
      mediaApps: [_TestMediaApp(runSession)],
    );
    addTearDown(sip.dispose);

    await sip.start();

    final call = await sip.originateCall(
      const SipOutboundCallRequest(
        trunkId: 'carrier-a',
        fromUri: 'sip:1000@pbx.example.com',
        toUri: 'sip:2000@example.com',
      ),
    );

    final attachedEventFuture = sip.callEvents.firstWhere(
      (event) => event.callId == call.id && event.mediaAppId == 'assistant',
    );
    final mediaSession = await call.attachMediaApp(mediaAppId: 'assistant');
    final appSession = await runSession.future.timeout(
      const Duration(seconds: 2),
    );
    final attachedEvent = await attachedEventFuture.timeout(
      const Duration(seconds: 2),
    );

    expect(appSession.call.id, call.id);
    expect(appSession.media.callId, call.id);
    expect(appSession.media.mediaAppId, 'assistant');
    expect(mediaSession.callId, call.id);
    expect(mediaSession.format, const SipAudioFormat.voiceAssistant());
    expect(attachedEvent.mediaAppId, 'assistant');

    await mediaSession.clearPlaybackQueue();

    await call.hangup();
    await mediaSession.closed.timeout(const Duration(seconds: 2));
    expect(mediaSession.isClosed, isTrue);
  });

  test('media session close signal completes when runtime closes it', () async {
    final session = SipRealtimeMediaSession.internal(
      callId: 'call-1',
      mediaAppId: 'assistant',
      format: const SipAudioFormat.voiceAssistant(),
      handle: 0,
      detach: () async {},
    );

    session.closeFromRuntime();

    await session.closed.timeout(const Duration(seconds: 1));
    expect(session.isClosed, isTrue);
  });
}

final class _TestMediaApp implements SipMediaApp {
  const _TestMediaApp(this.runSession);

  final Completer<SipMediaAppSession> runSession;

  @override
  String get id => 'assistant';

  @override
  Future<void> run(SipMediaAppSession session) async {
    if (!runSession.isCompleted) {
      runSession.complete(session);
    }
  }
}
