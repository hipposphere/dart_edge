import 'dart:async';

import 'package:dart_edge_sip/dart_edge_sip.dart';

final class AssistantSipDialplan implements SipDialplan {
  const AssistantSipDialplan({
    required this.assistantUser,
    required this.mediaAppId,
  });

  final String assistantUser;
  final String mediaAppId;

  @override
  FutureOr<SipDialplanDecision> onInboundInvite(SipInboundInvite invite) {
    final invitedUser = sipUriUser(invite.toUri);
    if (!_acceptsUser(invitedUser)) {
      return const SipDialplanDecision.reject(
        status: 404,
        reason: 'Unknown assistant extension',
      );
    }
    return SipDialplanDecision.routeToMediaApp(mediaAppId: mediaAppId);
  }

  @override
  FutureOr<SipDialplanDecision> onOutboundCall(SipOutboundCallRequest request) {
    return SipDialplanDecision.routeToTrunk(trunkId: request.trunkId);
  }

  bool _acceptsUser(String? invitedUser) {
    if (invitedUser == null) {
      return true;
    }
    return assistantUser == '*' || invitedUser == assistantUser;
  }
}

String? sipUriUser(String uri) {
  final schemeIndex = uri.indexOf(':');
  final atIndex = uri.indexOf('@');
  if (atIndex <= 0) {
    return null;
  }
  final start = schemeIndex >= 0 ? schemeIndex + 1 : 0;
  if (start >= atIndex) {
    return null;
  }
  return uri.substring(start, atIndex);
}
