final class SipTransferRequest {
  const SipTransferRequest({
    required this.targetUri,
    this.attendedCallId,
  });

  final String targetUri;
  final String? attendedCallId;

  Map<String, Object?> toJson() => {
    'targetUri': targetUri,
    if (attendedCallId case final attendedCallId?)
      'attendedCallId': attendedCallId,
  };
}

typedef _SipCallCommand = Future<void> Function(
  String kind, {
  Map<String, Object?> payload,
});

final class SipCallSession {
  SipCallSession.internal({
    required this.id,
    required _SipCallCommand execute,
  }) : _execute = execute;

  final String id;
  final _SipCallCommand _execute;

  Future<void> answer({int status = 200}) {
    return _execute('answer', payload: {'status': status});
  }

  Future<void> reject({int status = 486, String? reason}) {
    return _execute('reject', payload: {
      'status': status,
      if (reason case final reason?) 'reason': reason,
    });
  }

  Future<void> bridge(SipCallSession other) {
    return _execute('bridge', payload: {'otherCallId': other.id});
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

  Future<void> playPrompt({
    required String promptId,
    String? mediaUri,
  }) {
    return _execute('playPrompt', payload: {
      'promptId': promptId,
      if (mediaUri case final mediaUri?) 'mediaUri': mediaUri,
    });
  }

  Future<void> startRecording({
    required String recordingId,
    String? destinationUri,
  }) {
    return _execute('startRecording', payload: {
      'recordingId': recordingId,
      if (destinationUri case final destinationUri?)
        'destinationUri': destinationUri,
    });
  }

  Future<void> sendToVoicemail({required String mailbox}) {
    return _execute('sendToVoicemail', payload: {'mailbox': mailbox});
  }

  Future<void> hangup({int status = 487, String? reason}) {
    return _execute('hangup', payload: {
      'status': status,
      if (reason case final reason?) 'reason': reason,
    });
  }
}
