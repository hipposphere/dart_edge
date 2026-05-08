enum SipCallDirection {
  inbound,
  outbound;

  static SipCallDirection parse(String value) => switch (value) {
    'inbound' => inbound,
    'outbound' => outbound,
    _ => throw StateError('Unsupported SIP call direction: $value'),
  };
}

enum SipCallState {
  inviting,
  ringing,
  established,
  bridged,
  onHold,
  transferring,
  rejected,
  terminated;

  static SipCallState parse(String value) => switch (value) {
    'inviting' => inviting,
    'ringing' => ringing,
    'established' => established,
    'bridged' => bridged,
    'onHold' => onHold,
    'transferring' => transferring,
    'rejected' => rejected,
    'terminated' => terminated,
    _ => throw StateError('Unsupported SIP call state: $value'),
  };
}

enum SipRegistrationState {
  registered,
  unregistered,
  authenticationFailed;

  static SipRegistrationState parse(String value) => switch (value) {
    'registered' => registered,
    'unregistered' => unregistered,
    'authenticationFailed' => authenticationFailed,
    _ => throw StateError('Unsupported SIP registration state: $value'),
  };
}

enum SipTrunkState {
  connected,
  disconnected,
  failed;

  static SipTrunkState parse(String value) => switch (value) {
    'connected' => connected,
    'disconnected' => disconnected,
    'failed' => failed,
    _ => throw StateError('Unsupported SIP trunk state: $value'),
  };
}

enum SipRecordingState {
  started,
  stopped,
  completed;

  static SipRecordingState parse(String value) => switch (value) {
    'started' => started,
    'stopped' => stopped,
    'completed' => completed,
    _ => throw StateError('Unsupported SIP recording state: $value'),
  };
}

enum SipVoicemailState {
  queued,
  stored,
  failed;

  static SipVoicemailState parse(String value) => switch (value) {
    'queued' => queued,
    'stored' => stored,
    'failed' => failed,
    _ => throw StateError('Unsupported SIP voicemail state: $value'),
  };
}

sealed class SipEvent {
  const SipEvent({required this.timestamp, this.metadata = const {}});

  final DateTime timestamp;
  final Map<String, Object?> metadata;

  factory SipEvent.fromJson(Map<String, Object?> json) {
    return switch (json['category']) {
      'call' => SipCallEvent.fromJson(json),
      'registration' => SipRegistrationEvent.fromJson(json),
      'trunk' => SipTrunkEvent.fromJson(json),
      'recording' => SipRecordingEvent.fromJson(json),
      'voicemail' => SipVoicemailEvent.fromJson(json),
      final Object? value => throw StateError(
        'Unsupported SIP event category: $value',
      ),
    };
  }
}

final class SipCallEvent extends SipEvent {
  const SipCallEvent({
    required this.callId,
    required this.direction,
    required this.state,
    required super.timestamp,
    this.fromUri,
    this.toUri,
    this.relatedCallId,
    this.mediaAppId,
    super.metadata,
  });

  final String callId;
  final SipCallDirection direction;
  final SipCallState state;
  final String? fromUri;
  final String? toUri;
  final String? relatedCallId;
  final String? mediaAppId;

  factory SipCallEvent.fromJson(Map<String, Object?> json) {
    return SipCallEvent(
      callId: _readRequiredText(json, 'callId'),
      direction: SipCallDirection.parse(json['direction'] as String),
      state: SipCallState.parse(json['state'] as String),
      timestamp: _readTimestamp(json),
      fromUri: _readOptionalText(json, 'fromUri'),
      toUri: _readOptionalText(json, 'toUri'),
      relatedCallId: _readOptionalText(json, 'relatedCallId'),
      mediaAppId: _readOptionalText(json, 'mediaAppId'),
      metadata: _readMetadata(json),
    );
  }

  @override
  String toString() =>
      'SipCallEvent(callId: $callId, direction: $direction, state: $state, '
      'fromUri: $fromUri, toUri: $toUri, mediaAppId: $mediaAppId)';
}

final class SipRegistrationEvent extends SipEvent {
  const SipRegistrationEvent({
    required this.endpointId,
    required this.state,
    required super.timestamp,
    this.contactUri,
    super.metadata,
  });

  final String endpointId;
  final SipRegistrationState state;
  final String? contactUri;

  factory SipRegistrationEvent.fromJson(Map<String, Object?> json) {
    return SipRegistrationEvent(
      endpointId: _readRequiredText(json, 'endpointId'),
      state: SipRegistrationState.parse(json['state'] as String),
      timestamp: _readTimestamp(json),
      contactUri: _readOptionalText(json, 'contactUri'),
      metadata: _readMetadata(json),
    );
  }

  @override
  String toString() =>
      'SipRegistrationEvent(endpointId: $endpointId, state: $state, '
      'contactUri: $contactUri)';
}

final class SipTrunkEvent extends SipEvent {
  const SipTrunkEvent({
    required this.trunkId,
    required this.state,
    required super.timestamp,
    this.details,
    super.metadata,
  });

  final String trunkId;
  final SipTrunkState state;
  final String? details;

  factory SipTrunkEvent.fromJson(Map<String, Object?> json) {
    return SipTrunkEvent(
      trunkId: _readRequiredText(json, 'trunkId'),
      state: SipTrunkState.parse(json['state'] as String),
      timestamp: _readTimestamp(json),
      details: _readOptionalText(json, 'details'),
      metadata: _readMetadata(json),
    );
  }

  @override
  String toString() =>
      'SipTrunkEvent(trunkId: $trunkId, state: $state, details: $details)';
}

final class SipRecordingEvent extends SipEvent {
  const SipRecordingEvent({
    required this.callId,
    required this.recordingId,
    required this.state,
    required super.timestamp,
    this.storageUri,
    super.metadata,
  });

  final String callId;
  final String recordingId;
  final SipRecordingState state;
  final String? storageUri;

  factory SipRecordingEvent.fromJson(Map<String, Object?> json) {
    return SipRecordingEvent(
      callId: _readRequiredText(json, 'callId'),
      recordingId: _readRequiredText(json, 'recordingId'),
      state: SipRecordingState.parse(json['state'] as String),
      timestamp: _readTimestamp(json),
      storageUri: _readOptionalText(json, 'storageUri'),
      metadata: _readMetadata(json),
    );
  }

  @override
  String toString() =>
      'SipRecordingEvent(callId: $callId, recordingId: $recordingId, '
      'state: $state, storageUri: $storageUri)';
}

final class SipVoicemailEvent extends SipEvent {
  const SipVoicemailEvent({
    required this.callId,
    required this.mailbox,
    required this.state,
    required super.timestamp,
    this.messageId,
    this.storageUri,
    super.metadata,
  });

  final String callId;
  final String mailbox;
  final SipVoicemailState state;
  final String? messageId;
  final String? storageUri;

  factory SipVoicemailEvent.fromJson(Map<String, Object?> json) {
    return SipVoicemailEvent(
      callId: _readRequiredText(json, 'callId'),
      mailbox: _readRequiredText(json, 'mailbox'),
      state: SipVoicemailState.parse(json['state'] as String),
      timestamp: _readTimestamp(json),
      messageId: _readOptionalText(json, 'messageId'),
      storageUri: _readOptionalText(json, 'storageUri'),
      metadata: _readMetadata(json),
    );
  }

  @override
  String toString() =>
      'SipVoicemailEvent(callId: $callId, mailbox: $mailbox, '
      'state: $state, messageId: $messageId, storageUri: $storageUri)';
}

DateTime _readTimestamp(Map<String, Object?> json) {
  final value = json['timestamp'];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return DateTime.now().toUtc();
}

String _readRequiredText(Map<String, Object?> json, String key) {
  return _sipEventText(json[key] as String);
}

String? _readOptionalText(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? _sipEventText(value) : null;
}

Map<String, Object?> _readMetadata(Map<String, Object?> json) {
  final value = json['metadata'];
  if (value is Map<String, Object?>) {
    return {
      for (final entry in value.entries)
        _sipEventText(entry.key): _sanitizeSipEventJson(entry.value),
    };
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        _sipEventText('${entry.key}'): _sanitizeSipEventJson(entry.value),
    };
  }
  return const <String, Object?>{};
}

Object? _sanitizeSipEventJson(Object? value) {
  return switch (value) {
    final String text => _sipEventText(text),
    final List<Object?> list => [
      for (final value in list) _sanitizeSipEventJson(value),
    ],
    final Map<String, Object?> map => {
      for (final entry in map.entries)
        _sipEventText(entry.key): _sanitizeSipEventJson(entry.value),
    },
    final Map<Object?, Object?> map => {
      for (final entry in map.entries)
        _sipEventText('${entry.key}'): _sanitizeSipEventJson(entry.value),
    },
    _ => value,
  };
}

String _sipEventText(String value) => value.replaceAll('\u0000', '');
