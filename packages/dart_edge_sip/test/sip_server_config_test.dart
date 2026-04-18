import 'package:dart_edge_sip/dart_edge_sip.dart';
import 'package:test/test.dart';

void main() {
  test('serializes SIP server config with endpoints and trunks', () {
    const config = SipServerConfig(
      engine: PjsipEngineConfig(
        licenseMode: SipRuntimeLicenseMode.commercial,
        maxCalls: 1024,
        maxRegistrations: 12000,
        workerThreads: 4,
      ),
      transports: [
        SipTransportBinding.udp(host: '0.0.0.0', port: 5060),
        SipTransportBinding.tls(
          host: '0.0.0.0',
          port: 5061,
          tlsProfile: 'default',
        ),
      ],
      realms: [
        SipRealmConfig(domain: 'pbx.example.com', realm: 'pbx.example.com'),
      ],
      endpoints: [
        SipEndpointConfig(
          id: 'sales-1000',
          extension: '1000',
          username: '1000',
          password: 'secret',
          realm: 'pbx.example.com',
        ),
      ],
      trunks: [
        SipTrunkConfig(
          id: 'carrier-a',
          direction: SipTrunkDirection.bidirectional,
          serverUri: 'sip:carrier.example.net',
        ),
      ],
      recordings: SipRecordingStorageConfig.directory(
        directory: '/var/recordings',
        retentionDays: 14,
      ),
      voicemail: SipVoicemailStorageConfig.directory(
        directory: '/var/voicemail',
        defaultGreetingUri: 'file:///greetings/default.wav',
      ),
    );

    expect(config.toJson(), {
      'serverName': 'dart_edge_sip',
      'engine': {
        'kind': 'pjsip',
        'licenseMode': 'commercial',
        'maxCalls': 1024,
        'maxRegistrations': 12000,
        'maxConferencePorts': 32,
        'workerThreads': 4,
        'enableIce': true,
        'enableTurn': false,
        'enableTls': true,
        'enableSrtp': true,
        'enableRport': true,
        'userAgent': 'dart_edge_sip/0.1',
      },
      'transports': [
        {'protocol': 'udp', 'host': '0.0.0.0', 'port': 5060},
        {
          'protocol': 'tls',
          'host': '0.0.0.0',
          'port': 5061,
          'tlsProfile': 'default',
        },
      ],
      'realms': [
        {
          'domain': 'pbx.example.com',
          'realm': 'pbx.example.com',
          'requireAuthentication': true,
        },
      ],
      'endpoints': [
        {
          'id': 'sales-1000',
          'extension': '1000',
          'username': '1000',
          'password': 'secret',
          'realm': 'pbx.example.com',
          'allowRegistrations': true,
        },
      ],
      'trunks': [
        {
          'id': 'carrier-a',
          'direction': 'bidirectional',
          'serverUri': 'sip:carrier.example.net',
        },
      ],
      'media': {
        'rtpStartPort': 40000,
        'rtpEndPort': 40100,
        'enableSrtp': false,
        'enableDtmfDetection': true,
      },
      'recordings': {
        'enabled': true,
        'directory': '/var/recordings',
        'retentionDays': 14,
      },
      'voicemail': {
        'enabled': true,
        'directory': '/var/voicemail',
        'defaultGreetingUri': 'file:///greetings/default.wav',
      },
      'features': {
        'registrar': true,
        'authentication': true,
        'bridging': true,
        'transfers': true,
        'ivr': true,
        'recording': true,
        'voicemail': true,
      },
    });
  });
}
