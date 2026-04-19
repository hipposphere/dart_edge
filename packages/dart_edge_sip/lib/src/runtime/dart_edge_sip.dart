import 'dart:async';

import '../config/sip_server_config.dart';
import '../dialplan/sip_dialplan.dart';
import '../events/sip_events.dart';
import '../media/sip_audio.dart';
import '../media/sip_media_app.dart';
import '../media/sip_realtime_media_session.dart';
import '../native/dart_edge_sip_native.dart';
import 'sip_call_session.dart';

final class DartEdgeSip {
  DartEdgeSip({
    required SipServerConfig config,
    SipDialplan? dialplan,
    List<SipMediaApp> mediaApps = const <SipMediaApp>[],
    Duration eventPollInterval = const Duration(milliseconds: 200),
  }) : _config = config,
       _dialplan = dialplan,
       _mediaApps = List<SipMediaApp>.unmodifiable(mediaApps),
       _mediaAppsById = _indexMediaApps(mediaApps),
       _eventPollInterval = eventPollInterval;

  final SipServerConfig _config;
  final SipDialplan? _dialplan;
  final List<SipMediaApp> _mediaApps;
  final Map<String, SipMediaApp> _mediaAppsById;
  final Duration _eventPollInterval;
  final StreamController<SipEvent> _events =
      StreamController<SipEvent>.broadcast();
  final Map<String, SipRealtimeMediaSession> _mediaSessions =
      <String, SipRealtimeMediaSession>{};
  final Set<String> _handledInboundInvites = <String>{};

  int? _handle;
  Timer? _pollTimer;
  var _started = false;
  var _disposed = false;

  static int get nativeAbiVersion => DartEdgeSipNative.abiVersion;

  SipServerConfig get config => _config;

  SipDialplan? get dialplan => _dialplan;

  List<SipMediaApp> get mediaApps => _mediaApps;

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
    _closeAllMediaSessions();

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
    _ensureStarted();

    final mediaApp = _mediaAppsById[mediaAppId];
    if (mediaApp == null) {
      throw StateError("Unknown SIP media app '$mediaAppId'.");
    }

    final existing = _mediaSessions[call.id];
    if (existing != null && !existing.isClosed) {
      if (existing.mediaAppId == mediaAppId) {
        return existing;
      }
      await _detachMediaApp(call.id);
    }

    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': 'attachMediaApp',
      'sessionId': call.id,
      'payload': {'mediaAppId': mediaAppId},
    });

    final session = SipRealtimeMediaSession.internal(
      callId: call.id,
      mediaAppId: mediaAppId,
      format: const SipAudioFormat.voiceAssistant(),
      handle: _handle!,
      detach: () => _detachMediaApp(call.id),
    );
    _mediaSessions[call.id] = session;
    unawaited(_runMediaApp(mediaApp, call, session, metadata));
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
      _events.add(event);
      if (event case SipCallEvent(
        state: SipCallState.terminated,
        callId: final callId,
      )) {
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
          domain: _domainFromUri(event.toUri),
          metadata: Map<String, Object?>.unmodifiable(event.metadata),
        ),
      );
      await _applyInboundDialplanDecision(_session(event.callId), decision);
    } catch (error, stackTrace) {
      _events.addError(error, stackTrace);
    }
  }

  Future<void> _applyInboundDialplanDecision(
    SipCallSession call,
    SipDialplanDecision decision,
  ) async {
    switch (decision) {
      case SipRouteToMediaAppDecision(:final mediaAppId):
        await _issueCallCommand(
          call.id,
          'answer',
          payload: {'status': 200},
          drain: false,
        );
        await attachMediaApp(
          call,
          mediaAppId: mediaAppId,
          metadata: const {'source': 'dialplan'},
        );
      case SipRejectDecision(:final status, :final reason):
        await _issueCallCommand(
          call.id,
          'reject',
          payload: {
            'status': status,
            if (reason case final reason?) 'reason': reason,
          },
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
      case SipRouteToEndpointDecision():
        _events.addError(
          UnsupportedError(
            'Inbound routeToEndpoint is not wired in dart_edge_sip yet.',
          ),
        );
      case SipRouteToTrunkDecision():
        _events.addError(
          UnsupportedError(
            'Inbound routeToTrunk is not wired in dart_edge_sip yet.',
          ),
        );
    }
  }

  Future<void> _runMediaApp(
    SipMediaApp mediaApp,
    SipCallSession call,
    SipRealtimeMediaSession session,
    Map<String, Object?> metadata,
  ) async {
    try {
      await mediaApp.run(
        SipMediaAppSession(
          appId: mediaApp.id,
          call: call,
          media: session,
          metadata: Map<String, Object?>.unmodifiable(metadata),
        ),
      );
    } catch (error, stackTrace) {
      if (!_events.isClosed) {
        _events.addError(error, stackTrace);
      }
    }
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
