import 'dart:async';

import '../config/sip_server_config.dart';
import '../dialplan/sip_dialplan.dart';
import '../events/sip_events.dart';
import '../media/sip_media_app.dart';
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
       _eventPollInterval = eventPollInterval;

  final SipServerConfig _config;
  final SipDialplan? _dialplan;
  final List<SipMediaApp> _mediaApps;
  final Duration _eventPollInterval;
  final StreamController<SipEvent> _events = StreamController<SipEvent>.broadcast();

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

  Stream<SipCallEvent> get callEvents =>
      _events.stream.where((event) => event is SipCallEvent).cast<SipCallEvent>();

  Stream<SipRegistrationEvent> get registrationEvents =>
      _events.stream
          .where((event) => event is SipRegistrationEvent)
          .cast<SipRegistrationEvent>();

  Stream<SipTrunkEvent> get trunkEvents =>
      _events.stream.where((event) => event is SipTrunkEvent).cast<SipTrunkEvent>();

  Stream<SipRecordingEvent> get recordingEvents =>
      _events.stream
          .where((event) => event is SipRecordingEvent)
          .cast<SipRecordingEvent>();

  Stream<SipVoicemailEvent> get voicemailEvents =>
      _events.stream
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
      execute: (
        String kind, {
        Map<String, Object?> payload = const <String, Object?>{},
      }) {
        return _issueCallCommand(sessionId, kind, payload: payload);
      },
    );
  }

  Future<void> _issueCallCommand(
    String sessionId,
    String kind, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    _ensureStarted();
    DartEdgeSipNative.issueCommand(_handle!, {
      'kind': kind,
      'sessionId': sessionId,
      if (payload.isNotEmpty) 'payload': payload,
    });
    await _drainEvents();
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
      _events.add(SipEvent.fromJson(payload));
    }
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
