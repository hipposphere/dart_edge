import '../media/sip_realtime_media_session.dart';

final class SipTransferRequest {
  const SipTransferRequest({required this.targetUri, this.attendedCallId});

  final String targetUri;
  final String? attendedCallId;

  Map<String, Object?> toJson() => {
    'targetUri': targetUri,
    'attendedCallId': ?attendedCallId,
  };
}

typedef SipCallCommand =
    Future<void> Function(String kind, {Map<String, Object?> payload});

typedef SipAttachMediaApp =
    Future<SipRealtimeMediaSession> Function(
      String sessionId, {
      required String mediaAppId,
      Map<String, Object?> metadata,
    });

final class SipCallSession {
  SipCallSession.internal({
    required this.id,
    required this._execute,
    required this._attachMediaApp,
  });

  final String id;
  final SipCallCommand _execute;
  final SipAttachMediaApp _attachMediaApp;

  Future<void> answer({int status = 200}) {
    return _execute('answer', payload: {'status': status});
  }

  Future<void> reject({int status = 486, String? reason}) {
    return _execute('reject', payload: {'status': status, 'reason': ?reason});
  }

  Future<void> bridge(SipCallSession other) {
    return _execute('bridge', payload: {'otherCallId': other.id});
  }

  Future<void> routeToEndpoint({required String endpointId}) {
    return _execute('routeToEndpoint', payload: {'endpointId': endpointId});
  }

  Future<void> routeToTrunk({required String trunkId, String? targetUri}) {
    return _execute(
      'routeToTrunk',
      payload: {'trunkId': trunkId, 'targetUri': ?targetUri},
    );
  }

  Future<void> hold() {
    return _execute('hold');
  }

  Future<void> resume() {
    return _execute('resume');
  }

  Future<void> transfer(SipTransferRequest request) {
    return _execute('transfer', payload: request.toJson());
  }

  Future<void> playPrompt({required String promptId, String? mediaUri}) {
    return _execute(
      'playPrompt',
      payload: {'promptId': promptId, 'mediaUri': ?mediaUri},
    );
  }

  Future<void> startRecording({
    required String recordingId,
    String? destinationUri,
  }) {
    return _execute(
      'startRecording',
      payload: {'recordingId': recordingId, 'destinationUri': ?destinationUri},
    );
  }

  Future<void> sendToVoicemail({required String mailbox}) {
    return _execute('sendToVoicemail', payload: {'mailbox': mailbox});
  }

  Future<SipRealtimeMediaSession> attachMediaApp({
    required String mediaAppId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return _attachMediaApp(id, mediaAppId: mediaAppId, metadata: metadata);
  }

  Future<void> hangup({int status = 487, String? reason}) {
    return _execute('hangup', payload: {'status': status, 'reason': ?reason});
  }
}
