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

/// Optional capability for media apps that can establish external resources
/// before a SIP call is answered.
abstract interface class SipPreparableMediaApp implements SipMediaApp {
  FutureOr<SipMediaAppPreparation> prepare({
    required SipCallSession call,
    required SipMediaFormats formats,
    required Map<String, Object?> metadata,
  });
}

/// One prepared media-app instance owned by a single SIP call.
///
/// Implementations may hold provider connections or other resources between
/// [SipPreparableMediaApp.prepare] and attachment. [close] must be idempotent.
abstract interface class SipMediaAppPreparation {
  FutureOr<void> run(SipMediaAppSession session);

  FutureOr<void> close();
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
