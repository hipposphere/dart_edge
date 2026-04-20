import 'dart:async';

import 'package:dart_edge_sip/dart_edge_sip.dart';

Future<void> main() async {
  final sip = DartEdgeSip(
    dialplan: const _BasicDialplan(),
    config: SipServerConfig(
      engine: const PjsipEngineConfig(
        licenseMode: SipRuntimeLicenseMode.gpl,
        maxCalls: 4,
        maxConferencePorts: 32,
      ),
      transports: const [SipTransportBinding.udp(host: '0.0.0.0', port: 5060)],
      realms: const [
        SipRealmConfig(domain: 'pbx.example.com', realm: 'pbx.example.com'),
      ],
      endpoints: const [
        SipEndpointConfig(
          id: 'support-1000',
          extension: '1000',
          username: '1000',
          password: 'change-me',
          realm: 'pbx.example.com',
        ),
      ],
      trunks: const [
        SipTrunkConfig(
          id: 'carrier-a',
          direction: SipTrunkDirection.bidirectional,
          serverUri: 'sip:carrier.example.net',
        ),
      ],
      recordings: const SipRecordingStorageConfig.directory(
        directory: '/var/lib/dart_edge_sip/recordings',
      ),
      voicemail: const SipVoicemailStorageConfig.directory(
        directory: '/var/lib/dart_edge_sip/voicemail',
      ),
    ),
  );

  final subscription = sip.events.listen((event) {
    print('SIP event: $event');
  });

  await sip.start();

  final call = await sip.originateCall(
    const SipOutboundCallRequest(
      trunkId: 'carrier-a',
      fromUri: 'sip:1000@pbx.example.com',
      toUri: 'sip:+49301234567@carrier.example.net',
    ),
  );
  await call.hangup();

  await Future<void>.delayed(const Duration(milliseconds: 100));
  await sip.dispose();
  await subscription.cancel();
}

final class _BasicDialplan implements SipDialplan {
  const _BasicDialplan();

  @override
  FutureOr<SipDialplanDecision> onInboundInvite(SipInboundInvite invite) {
    final invitedUser = _sipUriUser(invite.toUri);
    if (invitedUser == '1000') {
      return const SipDialplanDecision.routeToEndpoint(
        endpointId: 'support-1000',
      );
    }
    return const SipDialplanDecision.routeToTrunk(trunkId: 'carrier-a');
  }

  @override
  FutureOr<SipDialplanDecision> onOutboundCall(SipOutboundCallRequest request) {
    return SipDialplanDecision.routeToTrunk(trunkId: request.trunkId);
  }
}

String? _sipUriUser(String uri) {
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
