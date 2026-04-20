import 'package:dart_edge_sip/dart_edge_sip.dart';

import 'gemini_live_config.dart';

final class CalloEngineConfig {
  const CalloEngineConfig({
    required this.bindHost,
    required this.bindPort,
    required this.testHost,
    required this.realm,
    required this.assistantUser,
    required this.testEndpointId,
    required this.testExtension,
    required this.testUsername,
    required this.testPassword,
    required this.rtpStartPort,
    required this.rtpEndPort,
    required this.externalAddress,
    required this.gemini,
  });

  factory CalloEngineConfig.fromEnvironment(
    Map<String, String> env, {
    String? geminiApiKey,
  }) {
    final apiKey = _firstPresent([geminiApiKey, env['GEMINI_API_KEY']]);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Missing Gemini API key. Pass --gemini-api-key or set GEMINI_API_KEY.',
      );
    }

    final bindHost = env['SIP_BIND_HOST'] ?? '0.0.0.0';
    final bindPort = _parsePort(env['SIP_BIND_PORT'], fallback: 5060);
    final testHost = env['SIP_TEST_HOST'] ?? '127.0.0.1';
    final testExtension = env['SIP_TEST_EXTENSION'] ?? '1000';
    final rtpStartPort = _parsePort(env['SIP_RTP_START_PORT'], fallback: 40000);
    final rtpEndPort = _parsePort(env['SIP_RTP_END_PORT'], fallback: 40100);
    final startupJingleDuration = Duration(
      seconds: _parseNonNegativeInt(
        env['CALLO_JINGLE_SECONDS'],
        fallback: 2,
        name: 'CALLO_JINGLE_SECONDS',
      ),
    );
    final externalAddress = _firstPresent([
      env['SIP_EXTERNAL_ADDRESS'],
      testHost,
    ]);

    return CalloEngineConfig(
      bindHost: bindHost,
      bindPort: bindPort,
      testHost: testHost,
      realm: env['SIP_REALM'] ?? testHost,
      assistantUser: env['CALLO_ASSISTANT_USER'] ?? 'assistant',
      testEndpointId: env['SIP_TEST_ENDPOINT_ID'] ?? 'test-phone',
      testExtension: testExtension,
      testUsername: env['SIP_TEST_USERNAME'] ?? testExtension,
      testPassword: env['SIP_TEST_PASSWORD'] ?? 'change-me',
      rtpStartPort: rtpStartPort,
      rtpEndPort: rtpEndPort,
      externalAddress: externalAddress,
      gemini: GeminiLiveConfig(
        apiKey: apiKey,
        model: env['GEMINI_LIVE_MODEL'] ?? defaultGeminiLiveModel,
        voiceName: env['GEMINI_VOICE_NAME'] ?? 'Kore',
        startupJingleDuration: startupJingleDuration,
        initialPrompt: env['CALLO_INITIAL_PROMPT'] ?? defaultInitialPrompt,
        systemPrompt: env['CALLO_SYSTEM_PROMPT'] ?? defaultSystemPrompt,
      ),
    );
  }

  final String bindHost;
  final int bindPort;
  final String testHost;
  final String realm;
  final String assistantUser;
  final String testEndpointId;
  final String testExtension;
  final String testUsername;
  final String testPassword;
  final int rtpStartPort;
  final int rtpEndPort;
  final String? externalAddress;
  final GeminiLiveConfig gemini;

  String get directSipUri => 'sip:$assistantUser@$testHost:$bindPort';

  String get registeredAssistantUri => 'sip:$assistantUser@$realm';

  SipServerConfig get sipConfig => SipServerConfig(
    serverName: 'callo_engine',
    engine: const PjsipEngineConfig(
      licenseMode: SipRuntimeLicenseMode.gpl,
      maxCalls: 4,
      maxConferencePorts: 32,
      enableIce: false,
      enableTurn: false,
      enableSrtp: false,
    ),
    transports: [
      SipTransportBinding.udp(host: bindHost, port: bindPort),
      SipTransportBinding.tcp(host: bindHost, port: bindPort),
    ],
    realms: [SipRealmConfig(domain: realm, realm: realm)],
    endpoints: [
      SipEndpointConfig(
        id: testEndpointId,
        extension: testExtension,
        username: testUsername,
        password: testPassword,
        realm: realm,
        displayName: 'Callo test phone',
      ),
    ],
    media: SipMediaConfig(
      rtpStartPort: rtpStartPort,
      rtpEndPort: rtpEndPort,
      externalAddress: externalAddress,
    ),
  );
}

String? _firstPresent(Iterable<String?> values) {
  for (final value in values) {
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

int _parsePort(String? value, {required int fallback}) {
  if (value == null || value.isEmpty) {
    return fallback;
  }
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0 || parsed > 65535) {
    throw StateError('Invalid port value: $value');
  }
  return parsed;
}

int _parseNonNegativeInt(
  String? value, {
  required int fallback,
  required String name,
}) {
  if (value == null || value.isEmpty) {
    return fallback;
  }
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw StateError('Invalid $name value: $value');
  }
  return parsed;
}
