import 'dart:async';

import '../runtime/sip_call_session.dart';

abstract interface class SipMediaApp {
  String get id;

  FutureOr<void> run(SipMediaAppSession session);
}

final class SipMediaAppSession {
  const SipMediaAppSession({
    required this.appId,
    required this.call,
    this.metadata = const <String, Object?>{},
  });

  final String appId;
  final SipCallSession call;
  final Map<String, Object?> metadata;
}
