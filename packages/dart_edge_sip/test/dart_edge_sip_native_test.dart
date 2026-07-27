import 'dart:async';
import 'dart:typed_data';

import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('loads the bundled dart_edge_sip native asset', () {
    expect(DartEdgeSip.nativeAbiVersion, 4);
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
      mediaApps: [
        _TestMediaApp(
          runSession,
          formats: const SipMediaFormats(
            capture: SipAudioFormat(
              sampleRateHz: 16000,
              channels: 1,
              frameDurationMs: 20,
            ),
            playback: SipAudioFormat(
              sampleRateHz: 24000,
              channels: 1,
              frameDurationMs: 20,
            ),
          ),
        ),
      ],
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
    expect(mediaSession.captureFormat, const SipAudioFormat.voiceAssistant());
    expect(
      mediaSession.playbackFormat,
      const SipAudioFormat(
        sampleRateHz: 24000,
        channels: 1,
        frameDurationMs: 20,
      ),
    );
    expect(attachedEvent.mediaAppId, 'assistant');

    await mediaSession.playAudioBytes(Uint8List(960));
    final queueStats = mediaSession.audioQueueStats;
    expect(queueStats.capture.capacityDuration, const Duration(seconds: 5));
    expect(queueStats.playback.capacityDuration, const Duration(seconds: 2));
    await mediaSession.clearPlaybackQueue();

    await call.hangup();
    await mediaSession.closed.timeout(const Duration(seconds: 2));
    expect(mediaSession.isClosed, isTrue);
  });

  test('prepares a capable media app before attachment', () async {
    final preparedCall = Completer<String>();
    final runSession = Completer<SipMediaAppSession>();
    final sip = DartEdgeSip(
      config: const SipServerConfig(
        transports: [SipTransportBinding.udp(host: '127.0.0.1', port: 5163)],
        trunks: [
          SipTrunkConfig(
            id: 'carrier-a',
            direction: SipTrunkDirection.bidirectional,
            serverUri: 'sip:example.com',
          ),
        ],
      ),
      mediaApps: [_PreparableTestMediaApp(preparedCall, runSession)],
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

    final prepared = await sip.prepareMediaApp(
      call,
      mediaAppId: 'prepared-assistant',
    );

    expect(await preparedCall.future, call.id);
    expect(runSession.isCompleted, isFalse);
    final media = await prepared.attach();
    expect((await runSession.future).media, same(media));
  });

  test('media session close signal completes when runtime closes it', () async {
    final session = SipRealtimeMediaSession.internal(
      callId: 'call-1',
      mediaAppId: 'assistant',
      captureFormat: const SipAudioFormat.voiceAssistant(),
      playbackFormat: const SipAudioFormat.voiceAssistant(),
      handle: 0,
      detach: () async {},
    );

    session.closeFromRuntime();

    await session.closed.timeout(const Duration(seconds: 1));
    expect(session.isClosed, isTrue);
  });

  test('can add, update, and remove trunks after runtime start', () async {
    final sip = DartEdgeSip(
      config: const SipServerConfig(
        engine: PjsipEngineConfig(maxCalls: 4, maxConferencePorts: 32),
        transports: [SipTransportBinding.udp(host: '127.0.0.1', port: 5162)],
      ),
    );
    addTearDown(sip.dispose);

    await sip.start();
    await sip.addTrunk(
      const SipTrunkConfig(
        id: 'carrier-b',
        direction: SipTrunkDirection.bidirectional,
        serverUri: 'sip:example.com',
      ),
    );
    expect(sip.trunks.map((trunk) => trunk.id), ['carrier-b']);

    final call = await sip.originateCall(
      const SipOutboundCallRequest(
        trunkId: 'carrier-b',
        fromUri: 'sip:1000@pbx.example.com',
        toUri: 'sip:2000@example.com',
      ),
    );
    await call.hangup();

    await sip.updateTrunk(
      'carrier-b',
      const SipTrunkConfig(
        id: 'carrier-c',
        direction: SipTrunkDirection.outbound,
        serverUri: 'sip:example.net',
      ),
    );
    expect(sip.trunks.map((trunk) => trunk.id), ['carrier-c']);
    await sip.removeTrunk('carrier-c');
    expect(sip.trunks, isEmpty);

    await expectLater(
      sip.originateCall(
        const SipOutboundCallRequest(
          trunkId: 'carrier-c',
          fromUri: 'sip:1000@pbx.example.com',
          toUri: 'sip:2000@example.com',
        ),
      ),
      throwsStateError,
    );
  });
}

final class _TestMediaApp implements SipMediaApp {
  const _TestMediaApp(this.runSession, {required this.formats});

  final Completer<SipMediaAppSession> runSession;
  final SipMediaFormats formats;

  @override
  String get id => 'assistant';

  @override
  SipMediaFormats audioFormats({
    required SipCallSession call,
    required Map<String, Object?> metadata,
  }) => formats;

  @override
  Future<void> run(SipMediaAppSession session) async {
    if (!runSession.isCompleted) {
      runSession.complete(session);
    }
    await session.media.closed;
  }
}

final class _PreparableTestMediaApp
    implements SipMediaApp, SipPreparableMediaApp {
  const _PreparableTestMediaApp(this.preparedCall, this.runSession);

  final Completer<String> preparedCall;
  final Completer<SipMediaAppSession> runSession;

  @override
  String get id => 'prepared-assistant';

  @override
  SipMediaFormats audioFormats({
    required SipCallSession call,
    required Map<String, Object?> metadata,
  }) => const SipMediaFormats.symmetric(SipAudioFormat.voiceAssistant());

  @override
  SipMediaAppPreparation prepare({
    required SipCallSession call,
    required SipMediaFormats formats,
    required Map<String, Object?> metadata,
  }) {
    preparedCall.complete(call.id);
    return _TestMediaAppPreparation(runSession);
  }

  @override
  Never run(SipMediaAppSession session) {
    throw StateError('Prepared media apps must run their prepared instance.');
  }
}

final class _TestMediaAppPreparation implements SipMediaAppPreparation {
  const _TestMediaAppPreparation(this.runSession);

  final Completer<SipMediaAppSession> runSession;

  @override
  void close() {}

  @override
  Future<void> run(SipMediaAppSession session) async {
    runSession.complete(session);
    await session.media.closed;
  }
}
