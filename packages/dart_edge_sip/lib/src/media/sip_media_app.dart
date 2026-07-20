import 'dart:async';

import '../runtime/sip_call_session.dart';
import 'sip_audio.dart';
import 'sip_realtime_media_session.dart';

abstract interface class SipMediaApp {
  String get id;

  FutureOr<SipMediaFormats> audioFormats({
    required SipCallSession call,
    required Map<String, Object?> metadata,
  });

  FutureOr<void> run(SipMediaAppSession session);
}

final class SipMediaAppSession {
  const SipMediaAppSession({
    required this.appId,
    required this.call,
    required this.media,
    this.metadata = const <String, Object?>{},
  });

  final String appId;
  final SipCallSession call;
  final SipRealtimeMediaSession media;
  final Map<String, Object?> metadata;
}
