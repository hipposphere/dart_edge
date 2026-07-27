import 'dart:async';

import '../config/sip_server_config.dart';
import '../config/sip_trunk_config.dart';
import '../dialplan/sip_dialplan.dart';
import '../events/sip_events.dart';
import '../media/sip_audio.dart';
import '../media/sip_media_app.dart';
import '../media/sip_realtime_media_session.dart';
import '../native/dart_edge_sip_native.dart';
import '../registrar/sip_registrar.dart';
import 'sip_call_session.dart';

enum SipMediaAppFailurePolicy { reportOnly, detach, hangup }

final class DartEdgeSip {
  DartEdgeSip({
    required SipServerConfig config,
    this._dialplan,
    List<SipMediaApp> mediaApps = const <SipMediaApp>[],
    this._eventPollInterval = const Duration(milliseconds: 200),
    this.mediaAppFailurePolicy = SipMediaAppFailurePolicy.hangup,
  }) : _config = config,
       _mediaApps = List<SipMediaApp>.unmodifiable(mediaApps),
       _mediaAppsById = _indexMediaApps(mediaApps),
       _trunks = List<SipTrunkConfig>.of(config.trunks);

  final SipServerConfig _config;
  final SipDialplan? _dialplan;
  final List<SipMediaApp> _mediaApps;
  final Map<String, SipMediaApp> _mediaAppsById;
  final List<SipTrunkConfig> _trunks;
  final Duration _eventPollInterval;
  final SipMediaAppFailurePolicy mediaAppFailurePolicy;
  final StreamController<SipEvent> _events =
      StreamController<SipEvent>.broadcast();
  final Map<String, SipRealtimeMediaSession> _mediaSessions =
      <String, SipRealtimeMediaSession>{};
  final Map<String, Set<SipPreparedMediaApp>> _preparedMediaApps =
      <String, Set<SipPreparedMediaApp>>{};
  final Map<String, SipCallState> _callStates = <String, SipCallState>{};
  final Set<String> _handledInboundInvites = <String>{};

  int? _handle;
  Timer? _pollTimer;
  var _started = false;
  var _disposed = false;

  static int get nativeAbiVersion => DartEdgeSipNative.abiVersion;

  SipServerConfig get config => _config;

  SipDialplan? get dialplan => _dialplan;

  List<SipMediaApp> get mediaApps => _mediaApps;

  List<SipTrunkConfig> get trunks => List<SipTrunkConfig>.unmodifiable(_trunks);

  bool get isStarted => _started;

  Stream<SipEvent> get events => _events.stream;

  Stream<SipCallEvent> get callEvents => _events.stream
      .where((event) => event is SipCallEvent)
      .cast<SipCallEvent>();

  Stream<SipRegistrationEvent> get registrationEvents => _events.stream
      .where((event) => event is SipRegistrationEvent)
      .cast<SipRegistrationEvent>();

  Stream<SipTrunkEvent> get trunkEvents => _events.stream
      .where((event) => event is SipTrunkEvent)
      .cast<SipTrunkEvent>();

  Stream<SipRecordingEvent> get recordingEvents => _events.stream
      .where((event) => event is SipRecordingEvent)
      .cast<SipRecordingEvent>();

  Stream<SipVoicemailEvent> get voicemailEvents => _events.stream
      .where((event) => event is SipVoicemailEvent)
      .cast<SipVoicemailEvent>();

  Stream<SipDtmfEvent> get dtmfEvents => _events.stream
      .where((event) => event is SipDtmfEvent)
      .cast<SipDtmfEvent>();

  Future<void> addTrunk(SipTrunkConfig trunk) async {
    _ensureStarted();

    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'addTrunk',
      'payload': {'trunk': trunk.toJson()},
    });
    _trunks.add(trunk);
    await _drainEvents();
  }

  Future<void> updateTrunk(String trunkId, SipTrunkConfig trunk) async {
    _ensureStarted();

    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'updateTrunk',
      'payload': {'trunkId': trunkId, 'trunk': trunk.toJson()},
    });
    final index = _trunks.indexWhere((trunk) => trunk.id == trunkId);
    if (index >= 0) {
      _trunks[index] = trunk;
    }
    await _drainEvents();
  }

  Future<void> removeTrunk(String trunkId) async {
    _ensureStarted();

    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'removeTrunk',
      'payload': {'trunkId': trunkId},
    });
    _trunks.removeWhere((trunk) => trunk.id == trunkId);
    await _drainEvents();
  }

  Future<void> setTrunkRegistration(
    String trunkId, {
    required bool enabled,
  }) async {
    _ensureStarted();

    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'setTrunkRegistration',
      'payload': {'trunkId': trunkId, 'enabled': enabled},
    });
    await _drainEvents();
  }

  Future<void> start() async {
    _ensureNotDisposed();
    if (_started) {
      return;
    }

    final handle = _handle ??= DartEdgeSipNative.create(_config);
    DartEdgeSipNative.start(handle);
    _started = true;
    _pollTimer = Timer.periodic(_eventPollInterval, (_) {
      unawaited(_drainEvents());
    });
    await _drainEvents();
  }

  Future<void> stop() async {
    if (!_started) {
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = null;
    await _closeAllPreparedMediaApps();
    _closeAllMediaSessions();
    _callStates.clear();
    _handledInboundInvites.clear();

    final handle = _handle;
    if (handle != null) {
      DartEdgeSipNative.stop(handle);
    }
    _started = false;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await stop();
    final handle = _handle;
    if (handle != null) {
      DartEdgeSipNative.dispose(handle);
      _handle = null;
    }

    await _events.close();
  }

  Future<SipCallSession> originateCall(SipOutboundCallRequest request) async {
    _ensureStarted();

    final dialplan = _dialplan;
    if (dialplan != null) {
      final decision = await dialplan.onOutboundCall(request);
      switch (decision) {
        case SipRouteToTrunkDecision(:final trunkId, :final targetUri):
          request = SipOutboundCallRequest(
            trunkId: trunkId,
            fromUri: request.fromUri,
            toUri: targetUri ?? request.toUri,
            headers: request.headers,
            metadata: request.metadata,
          );
        case SipRouteToEndpointDecision(:final endpointId):
          return callEndpoint(
            SipEndpointCallRequest(
              endpointId: endpointId,
              fromUri: request.fromUri,
              metadata: request.metadata,
            ),
          );
        case SipRejectDecision(:final status, :final reason):
          throw StateError(
            'Outbound SIP call rejected by dialplan '
            '($status${reason == null ? '' : ', $reason'}).',
          );
        case SipRouteToMediaAppDecision():
        case SipSendToVoicemailDecision():
          throw UnsupportedError(
            'Outbound SIP calls must route to a trunk or registered endpoint.',
          );
      }
    }

    final payload = DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'originateCall',
      'request': request.toJson(),
    });
    await _drainEvents();

    final sessionId = payload['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      throw StateError('dart_edge_sip originateCall returned no sessionId.');
    }

    return _session(sessionId);
  }

  Future<SipCallSession> callEndpoint(SipEndpointCallRequest request) async {
    _ensureStarted();

    final payload = DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'originateEndpointCall',
      'request': request.toJson(),
    });
    await _drainEvents();

    final sessionId = payload['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      throw StateError(
        'dart_edge_sip originateEndpointCall returned no sessionId.',
      );
    }

    return _session(sessionId);
  }

  Future<List<SipRegisteredEndpoint>> registeredEndpoints() async {
    _ensureStarted();

    final payload = DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'registeredEndpoints',
    });
    await _drainEvents();

    final endpoints = payload['endpoints'];
    if (endpoints is! List) {
      throw StateError(
        'dart_edge_sip registeredEndpoints returned no endpoint list.',
      );
    }

    return [
      for (final endpoint in endpoints)
        SipRegisteredEndpoint.fromJson(
          (endpoint as Map).cast<String, Object?>(),
        ),
    ];
  }

  Future<SipRegisteredEndpoint?> registeredEndpoint(String endpointId) async {
    final endpoints = await registeredEndpoints();
    for (final endpoint in endpoints) {
      if (endpoint.endpointId == endpointId) {
        return endpoint;
      }
    }
    return null;
  }

  SipCallSession _session(String sessionId) {
    return SipCallSession.internal(
      id: sessionId,
      execute:
          (
            String kind, {
            Map<String, Object?> payload = const <String, Object?>{},
          }) {
            return _issueCallCommand(sessionId, kind, payload: payload);
          },
      attachMediaApp:
          (
            String sessionId, {
            required String mediaAppId,
            Map<String, Object?> metadata = const <String, Object?>{},
          }) {
            return attachMediaApp(
              _session(sessionId),
              mediaAppId: mediaAppId,
              metadata: metadata,
            );
          },
    );
  }

  Future<SipRealtimeMediaSession> attachMediaApp(
    SipCallSession call, {
    required String mediaAppId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    final prepared = await prepareMediaApp(
      call,
      mediaAppId: mediaAppId,
      metadata: metadata,
    );
    return prepared.attach();
  }

  /// Prepares a media app without answering or attaching it to the call.
  ///
  /// This allows applications to establish an AI/provider session while the
  /// SIP leg is still ringing and then atomically answer and attach.
  Future<SipPreparedMediaApp> prepareMediaApp(
    SipCallSession call, {
    required String mediaAppId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    _ensureStarted();

    final mediaApp = _mediaAppsById[mediaAppId];
    if (mediaApp == null) {
      throw StateError("Unknown SIP media app '$mediaAppId'.");
    }
    final formats = await mediaApp.audioFormats(
      call: call,
      metadata: Map<String, Object?>.unmodifiable(metadata),
    );
    _validateMediaAppFormat(formats.capture, direction: 'capture');
    _validateMediaAppFormat(formats.playback, direction: 'playback');
    _validateMediaBufferDuration(
      formats.buffers.captureDuration,
      frameDurationMs: formats.capture.frameDurationMs,
      direction: 'capture',
    );
    _validateMediaBufferDuration(
      formats.buffers.playbackDuration,
      frameDurationMs: formats.playback.frameDurationMs,
      direction: 'playback',
    );
    final immutableMetadata = Map<String, Object?>.unmodifiable(metadata);
    final preparation = mediaApp is SipPreparableMediaApp
        ? await mediaApp.prepare(
            call: call,
            formats: formats,
            metadata: immutableMetadata,
          )
        : _LegacySipMediaAppPreparation(mediaApp);
    final callStateAfterPreparation = _callStates[call.id];
    if (callStateAfterPreparation == SipCallState.terminated ||
        callStateAfterPreparation == SipCallState.rejected) {
      await preparation.close();
      throw StateError(
        'SIP call ${call.id} ended while its media app was being prepared.',
      );
    }
    late final SipPreparedMediaApp prepared;
    prepared = SipPreparedMediaApp._(
      call: call,
      mediaAppId: mediaAppId,
      formats: formats,
      attach: ({required bool answer, required int answerStatus}) async {
        var answerRequested = false;
        try {
          if (answer) {
            answerRequested = true;
            await _issueCallCommand(
              call.id,
              'answer',
              payload: {'status': answerStatus},
            );
            await _waitForCallState(call.id, SipCallState.established);
            if (_callStates[call.id] != SipCallState.established) {
              throw StateError(
                'SIP call ${call.id} did not become established before media attachment.',
              );
            }
          }
          final session = await _attachPreparedMediaApp(
            call,
            mediaAppId: mediaAppId,
            formats: formats,
            metadata: immutableMetadata,
            preparation: preparation,
          );
          _forgetPreparedMediaApp(prepared);
          return session;
        } catch (error, stackTrace) {
          if (answerRequested) {
            await _hangupAfterPreparedAttachFailure(call);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
      closePreparation: () async {
        _forgetPreparedMediaApp(prepared);
        await preparation.close();
      },
    );
    _preparedMediaApps
        .putIfAbsent(call.id, () => <SipPreparedMediaApp>{})
        .add(prepared);
    return prepared;
  }

  Future<void> _hangupAfterPreparedAttachFailure(SipCallSession call) async {
    try {
      await _issueCallCommand(
        call.id,
        'hangup',
        payload: const {
          'status': 500,
          'reason': 'Prepared SIP media attachment failed.',
        },
      );
    } catch (error, stackTrace) {
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
    }
  }

  Future<SipRealtimeMediaSession> _attachPreparedMediaApp(
    SipCallSession call, {
    required String mediaAppId,
    required SipMediaFormats formats,
    required Map<String, Object?> metadata,
    required SipMediaAppPreparation preparation,
  }) async {
    _ensureStarted();

    final existing = _mediaSessions[call.id];
    if (existing != null && !existing.isClosed) {
      if (existing.mediaAppId == mediaAppId &&
          existing.captureFormat == formats.capture &&
          existing.playbackFormat == formats.playback) {
        return existing;
      }
      await _detachMediaApp(call.id);
    }

    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'attachMediaApp',
      'sessionId': call.id,
      'payload': {
        'mediaAppId': mediaAppId,
        'captureSampleRateHz': formats.capture.sampleRateHz,
        'captureChannels': formats.capture.channels,
        'captureFrameDurationMs': formats.capture.frameDurationMs,
        'playbackSampleRateHz': formats.playback.sampleRateHz,
        'playbackChannels': formats.playback.channels,
        'playbackFrameDurationMs': formats.playback.frameDurationMs,
        'captureBufferDurationMs':
            formats.buffers.captureDuration.inMilliseconds,
        'playbackBufferDurationMs':
            formats.buffers.playbackDuration.inMilliseconds,
      },
    });

    final session = SipRealtimeMediaSession.internal(
      callId: call.id,
      mediaAppId: mediaAppId,
      captureFormat: formats.capture,
      playbackFormat: formats.playback,
      handle: _handle!,
      detach: () => _detachMediaApp(call.id),
    );
    _mediaSessions[call.id] = session;
    unawaited(_runPreparedMediaApp(preparation, call, session, metadata));
    await _drainEvents();
    return session;
  }

  Future<void> _issueCallCommand(
    String sessionId,
    String kind, {
    Map<String, Object?> payload = const <String, Object?>{},
    bool drain = true,
  }) async {
    _ensureStarted();
    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': kind,
      'sessionId': sessionId,
      if (payload.isNotEmpty) 'payload': payload,
    });
    if (drain) {
      await _drainEvents();
    }
  }

  Future<void> _drainEvents() async {
    final handle = _handle;
    if (!_started || handle == null || _events.isClosed) {
      return;
    }

    while (true) {
      final payload = DartEdgeSipNative.pollEvent(handle);
      if (payload == null) {
        break;
      }
      final event = SipEvent.fromJson(payload);
      if (event case SipCallEvent(:final callId, :final state)) {
        _callStates[callId] = state;
      }
      _events.add(event);
      if (event case SipCallEvent(
        state: SipCallState.terminated,
        callId: final callId,
      )) {
        await _closePreparedMediaApps(callId);
        _closeMediaSession(callId);
        _handledInboundInvites.remove(callId);
      } else if (event case SipCallEvent(
        direction: SipCallDirection.inbound,
        state: SipCallState.inviting,
      )) {
        await _maybeHandleInboundInvite(event);
      }
    }
  }

  Future<void> _waitForCallState(
    String callId,
    SipCallState expectedState, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_started && !_events.isClosed) {
      await _drainEvents();
      final state = _callStates[callId];
      if (state == expectedState ||
          state == SipCallState.terminated ||
          state == SipCallState.rejected) {
        return;
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        return;
      }
      final delay = remaining < const Duration(milliseconds: 20)
          ? remaining
          : const Duration(milliseconds: 20);
      await Future<void>.delayed(delay);
    }
  }

  Future<void> _maybeHandleInboundInvite(SipCallEvent event) async {
    final dialplan = _dialplan;
    if (dialplan == null || !_handledInboundInvites.add(event.callId)) {
      return;
    }

    try {
      final decision = await dialplan.onInboundInvite(
        SipInboundInvite(
          callId: event.callId,
          fromUri: event.fromUri ?? '',
          toUri: event.toUri ?? '',
          trunkId: event.trunkId,
          domain: _domainFromUri(event.toUri),
          metadata: Map<String, Object?>.unmodifiable(event.metadata),
        ),
      );
      await _applyInboundDialplanDecision(_session(event.callId), decision);
    } catch (error, stackTrace) {
      try {
        await _issueCallCommand(
          event.callId,
          'reject',
          payload: const {
            'status': 500,
            'reason': 'SIP media preparation failed.',
          },
          drain: false,
        );
      } catch (rejectError, rejectStackTrace) {
        if (!_events.isClosed) {
          _events.addError(rejectError, rejectStackTrace);
        }
      }
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
    }
  }

  Future<void> _applyInboundDialplanDecision(
    SipCallSession call,
    SipDialplanDecision decision,
  ) async {
    switch (decision) {
      case SipRouteToMediaAppDecision(:final mediaAppId):
        final prepared = await prepareMediaApp(
          call,
          mediaAppId: mediaAppId,
          metadata: const {'source': 'dialplan'},
        );
        await prepared.answerAndAttach();
      case SipRejectDecision(:final status, :final reason):
        await _issueCallCommand(
          call.id,
          'reject',
          payload: {'status': status, 'reason': ?reason},
          drain: false,
        );
      case SipSendToVoicemailDecision(:final mailbox):
        await _issueCallCommand(
          call.id,
          'answer',
          payload: {'status': 200},
          drain: false,
        );
        await _issueCallCommand(
          call.id,
          'sendToVoicemail',
          payload: {'mailbox': mailbox},
          drain: false,
        );
      case SipRouteToEndpointDecision(:final endpointId):
        await _issueCallCommand(
          call.id,
          'routeToEndpoint',
          payload: {'endpointId': endpointId},
          drain: false,
        );
      case SipRouteToTrunkDecision(:final trunkId, :final targetUri):
        await _issueCallCommand(
          call.id,
          'routeToTrunk',
          payload: {'trunkId': trunkId, 'targetUri': ?targetUri},
          drain: false,
        );
    }
  }

  Future<void> _runPreparedMediaApp(
    SipMediaAppPreparation preparation,
    SipCallSession call,
    SipRealtimeMediaSession session,
    Map<String, Object?> metadata,
  ) async {
    var failed = false;
    try {
      await preparation.run(
        SipMediaAppSession(
          appId: session.mediaAppId,
          call: call,
          media: session,
          metadata: Map<String, Object?>.unmodifiable(metadata),
        ),
      );
    } catch (error, stackTrace) {
      failed = true;
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
    } finally {
      if (!session.isClosed) {
        await _handleMediaAppTermination(call, session, failed: failed);
      }
      try {
        await preparation.close();
      } catch (error, stackTrace) {
        if (!_events.isClosed) {
          _events.addError(error, stackTrace);
        }
      }
    }
  }

  Future<void> _handleMediaAppTermination(
    SipCallSession call,
    SipRealtimeMediaSession session, {
    required bool failed,
  }) async {
    try {
      switch (mediaAppFailurePolicy) {
        case SipMediaAppFailurePolicy.reportOnly:
          return;
        case SipMediaAppFailurePolicy.detach:
          await _detachMediaApp(call.id);
        case SipMediaAppFailurePolicy.hangup:
          await _issueCallCommand(
            call.id,
            'hangup',
            payload: {
              'status': failed ? 500 : 200,
              'reason': failed
                  ? 'SIP media app failed.'
                  : 'SIP media app ended.',
            },
          );
          if (!session.isClosed) {
            await _detachMediaApp(call.id);
          }
      }
    } catch (error, stackTrace) {
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
      if (!session.isClosed) {
        await _detachMediaApp(call.id).catchError((_) {});
      }
    }
  }

  void _forgetPreparedMediaApp(SipPreparedMediaApp prepared) {
    final preparedForCall = _preparedMediaApps[prepared.call.id];
    preparedForCall?.remove(prepared);
    if (preparedForCall?.isEmpty ?? false) {
      _preparedMediaApps.remove(prepared.call.id);
    }
  }

  Future<void> _closePreparedMediaApps(String callId) async {
    final prepared = _preparedMediaApps.remove(callId);
    if (prepared == null) {
      return;
    }
    await Future.wait(prepared.map((instance) => instance.close()));
  }

  Future<void> _closeAllPreparedMediaApps() async {
    final prepared = _preparedMediaApps.values
        .expand((values) => values)
        .toList();
    _preparedMediaApps.clear();
    await Future.wait(prepared.map((instance) => instance.close()));
  }

  Future<void> _detachMediaApp(String callId) async {
    final session = _mediaSessions.remove(callId);
    if (session != null) {
      session.closeFromRuntime();
    }

    if (!_started || _handle == null) {
      return;
    }

    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'detachMediaApp',
      'sessionId': callId,
    });
    await _drainEvents();
  }

  void _closeMediaSession(String callId) {
    final session = _mediaSessions.remove(callId);
    session?.closeFromRuntime();
  }

  void _closeAllMediaSessions() {
    final callIds = _mediaSessions.keys.toList(growable: false);
    for (final callId in callIds) {
      _closeMediaSession(callId);
    }
  }

  static Map<String, SipMediaApp> _indexMediaApps(
    Iterable<SipMediaApp> mediaApps,
  ) {
    final byId = <String, SipMediaApp>{};
    for (final mediaApp in mediaApps) {
      final previous = byId[mediaApp.id];
      if (previous != null) {
        throw StateError("Duplicate SIP media app ID '${mediaApp.id}'.");
      }
      byId[mediaApp.id] = mediaApp;
    }
    return Map<String, SipMediaApp>.unmodifiable(byId);
  }

  static String? _domainFromUri(String? uri) {
    if (uri == null || uri.isEmpty) {
      return null;
    }
    final atIndex = uri.indexOf('@');
    if (atIndex < 0 || atIndex + 1 >= uri.length) {
      return null;
    }
    final start = atIndex + 1;
    final semicolonIndex = uri.indexOf(';', start);
    final end = semicolonIndex >= 0 ? semicolonIndex : uri.length;
    final host = uri.substring(start, end);
    return host.isEmpty ? null : host;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('DartEdgeSip has already been disposed.');
    }
  }

  void _ensureStarted() {
    _ensureNotDisposed();
    if (!_started || _handle == null) {
      throw StateError('DartEdgeSip is not started.');
    }
  }
}

typedef SipPreparedMediaAppAttach =
    Future<SipRealtimeMediaSession> Function({
      required bool answer,
      required int answerStatus,
    });

/// A media app whose external resources are ready before SIP answer.
final class SipPreparedMediaApp {
  SipPreparedMediaApp._({
    required this.call,
    required this.mediaAppId,
    required this.formats,
    required this._attach,
    required this._closePreparation,
  });

  final SipCallSession call;
  final String mediaAppId;
  final SipMediaFormats formats;
  final SipPreparedMediaAppAttach _attach;
  final Future<void> Function() _closePreparation;

  Future<SipRealtimeMediaSession>? _attachment;
  var _attached = false;
  var _closed = false;

  bool get isAttached => _attached;

  bool get isClosed => _closed;

  Future<SipRealtimeMediaSession> attach() {
    return _attachOnce(answer: false, answerStatus: 200);
  }

  Future<SipRealtimeMediaSession> answerAndAttach({int status = 200}) {
    if (status < 200 || status >= 300) {
      throw ArgumentError.value(
        status,
        'status',
        'Prepared media apps require a successful final SIP answer.',
      );
    }
    return _attachOnce(answer: true, answerStatus: status);
  }

  Future<SipRealtimeMediaSession> _attachOnce({
    required bool answer,
    required int answerStatus,
  }) {
    if (_closed) {
      throw StateError('The prepared SIP media app has already been closed.');
    }
    final existing = _attachment;
    if (existing != null) {
      return existing;
    }
    final operation = _performAttach(
      answer: answer,
      answerStatus: answerStatus,
    );
    _attachment = operation;
    return operation;
  }

  Future<SipRealtimeMediaSession> _performAttach({
    required bool answer,
    required int answerStatus,
  }) async {
    try {
      final session = await _attach(answer: answer, answerStatus: answerStatus);
      _attached = true;
      return session;
    } catch (error, stackTrace) {
      _attachment = null;
      _closed = true;
      try {
        await _closePreparation();
      } catch (_) {
        // Preserve the attachment failure, which is the actionable cause.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> close() async {
    if (_closed || _attachment != null) {
      return;
    }
    _closed = true;
    await _closePreparation();
  }
}

final class _LegacySipMediaAppPreparation implements SipMediaAppPreparation {
  const _LegacySipMediaAppPreparation(this._mediaApp);

  final SipMediaApp _mediaApp;

  @override
  FutureOr<void> run(SipMediaAppSession session) => _mediaApp.run(session);

  @override
  void close() {}
}

void _validateMediaAppFormat(
  SipAudioFormat format, {
  required String direction,
}) {
  if (format.encoding != SipAudioEncoding.pcm16le) {
    throw ArgumentError.value(
      format.encoding,
      '$direction.encoding',
      'SIP media apps currently require PCM16LE audio.',
    );
  }
  if (format.sampleRateHz <= 0 || format.sampleRateHz > 192000) {
    throw ArgumentError.value(
      format.sampleRateHz,
      '$direction.sampleRateHz',
      'SIP media app sample rate must be between 1 and 192000 Hz.',
    );
  }
  if (format.channels != 1) {
    throw ArgumentError.value(
      format.channels,
      '$direction.channels',
      'SIP media apps currently require mono audio.',
    );
  }
  if (format.frameDurationMs <= 0 ||
      format.frameDurationMs > 1000 ||
      format.bytesPerFrame > 4096) {
    throw ArgumentError.value(
      format.frameDurationMs,
      '$direction.frameDurationMs',
      'SIP media app frames must be positive and no larger than 4096 bytes.',
    );
  }
}

void _validateMediaBufferDuration(
  Duration duration, {
  required int frameDurationMs,
  required String direction,
}) {
  if (duration.inMilliseconds < frameDurationMs ||
      duration > const Duration(minutes: 1)) {
    throw ArgumentError.value(
      duration,
      '$direction.bufferDuration',
      'SIP media buffer duration must contain at least one frame and not exceed one minute.',
    );
  }
}
