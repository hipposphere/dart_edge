import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('serializes endpoint call requests', () {
    const request = SipEndpointCallRequest(
      endpointId: 'sales-1000',
      fromUri: 'sip:operator@pbx.example.com',
      metadata: {'reason': 'callback'},
    );

    expect(request.toJson(), {
      'endpointId': 'sales-1000',
      'fromUri': 'sip:operator@pbx.example.com',
      'metadata': {'reason': 'callback'},
    });
  });

  test('parses registered endpoint snapshots', () {
    final endpoint = SipRegisteredEndpoint.fromJson({
      'endpointId': 'sales-1000',
      'contactUri': 'sip:1000@192.0.2.10:5060',
      'expiresAtEpochSeconds': 1800000000,
      'metadata': {'transport': 'udp'},
    });

    expect(endpoint.endpointId, 'sales-1000');
    expect(endpoint.contactUri, 'sip:1000@192.0.2.10:5060');
    expect(
      endpoint.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000, isUtc: true),
    );
    expect(endpoint.metadata, {'transport': 'udp'});
  });

  test('keeps route-to-trunk target URI optional', () {
    const decision = SipDialplanDecision.routeToTrunk(
      trunkId: 'carrier-a',
      targetUri: 'sip:+49301234567@carrier.example.net',
    );

    expect(decision, isA<SipRouteToTrunkDecision>());
    final route = decision as SipRouteToTrunkDecision;
    expect(route.trunkId, 'carrier-a');
    expect(route.targetUri, 'sip:+49301234567@carrier.example.net');
  });
}
