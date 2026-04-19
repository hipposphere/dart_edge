import 'dart:async';

final class SipInboundInvite {
  const SipInboundInvite({
    required this.callId,
    required this.fromUri,
    required this.toUri,
    this.domain,
    this.headers = const <String, String>{},
    this.metadata = const <String, Object?>{},
  });

  final String callId;
  final String fromUri;
  final String toUri;
  final String? domain;
  final Map<String, String> headers;
  final Map<String, Object?> metadata;
}

final class SipOutboundCallRequest {
  const SipOutboundCallRequest({
    required this.trunkId,
    required this.fromUri,
    required this.toUri,
    this.headers = const <String, String>{},
    this.metadata = const <String, Object?>{},
  });

  final String trunkId;
  final String fromUri;
  final String toUri;
  final Map<String, String> headers;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'trunkId': trunkId,
    'fromUri': fromUri,
    'toUri': toUri,
    if (headers.isNotEmpty) 'headers': headers,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

sealed class SipDialplanDecision {
  const SipDialplanDecision();

  const factory SipDialplanDecision.routeToEndpoint({
    required String endpointId,
  }) = SipRouteToEndpointDecision;

  const factory SipDialplanDecision.routeToTrunk({required String trunkId}) =
      SipRouteToTrunkDecision;

  const factory SipDialplanDecision.routeToMediaApp({
    required String mediaAppId,
  }) = SipRouteToMediaAppDecision;

  const factory SipDialplanDecision.sendToVoicemail({required String mailbox}) =
      SipSendToVoicemailDecision;

  const factory SipDialplanDecision.reject({
    required int status,
    String? reason,
  }) = SipRejectDecision;
}

final class SipRouteToEndpointDecision implements SipDialplanDecision {
  const SipRouteToEndpointDecision({required this.endpointId});

  final String endpointId;
}

final class SipRouteToTrunkDecision implements SipDialplanDecision {
  const SipRouteToTrunkDecision({required this.trunkId});

  final String trunkId;
}

final class SipRouteToMediaAppDecision implements SipDialplanDecision {
  const SipRouteToMediaAppDecision({required this.mediaAppId});

  final String mediaAppId;
}

final class SipSendToVoicemailDecision implements SipDialplanDecision {
  const SipSendToVoicemailDecision({required this.mailbox});

  final String mailbox;
}

final class SipRejectDecision implements SipDialplanDecision {
  const SipRejectDecision({required this.status, this.reason});

  final int status;
  final String? reason;
}

abstract interface class SipDialplan {
  FutureOr<SipDialplanDecision> onInboundInvite(SipInboundInvite invite);

  FutureOr<SipDialplanDecision> onOutboundCall(SipOutboundCallRequest request);
}
