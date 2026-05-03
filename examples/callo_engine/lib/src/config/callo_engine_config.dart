import 'package:dart_edge_sip/dart_edge_sip.dart';

import 'gemini_live_config.dart';

final class CalloEngineConfig {
  const CalloEngineConfig({
    required this.bindHost,
    required this.bindPort,
    required this.assistantUser,
    required this.trunkId,
    required this.trunkServerUri,
    required this.trunkUsername,
    required this.trunkPassword,
    required this.trunkRealm,
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
    final trunkUsername = _firstPresent([env['SIP_TRUNK_USERNAME']]);
    final trunkPassword = _firstPresent([env['SIP_TRUNK_PASSWORD']]);
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
      env['SIP_PUBLIC_ADDRESS'],
    ]);

    if (trunkUsername == null || trunkPassword == null) {
      throw StateError(
        'Missing SIP trunk credentials. Set SIP_TRUNK_USERNAME and '
        'SIP_TRUNK_PASSWORD so Callo Engine can register with the trunk.',
      );
    }

    return CalloEngineConfig(
      bindHost: bindHost,
      bindPort: bindPort,
      assistantUser: env['CALLO_ASSISTANT_USER'] ?? 'assistant',
      trunkId: env['SIP_TRUNK_ID'] ?? 'easybell',
      trunkServerUri: env['SIP_TRUNK_SERVER_URI'] ?? 'sip:voip.easybell.de',
      trunkUsername: trunkUsername,
      trunkPassword: trunkPassword,
      trunkRealm: env['SIP_TRUNK_REALM'] ?? 'voip.easybell.de',
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
  final String assistantUser;
  final String trunkId;
  final String trunkServerUri;
  final String trunkUsername;
  final String trunkPassword;
  final String trunkRealm;
  final int rtpStartPort;
  final int rtpEndPort;
  final String? externalAddress;
  final GeminiLiveConfig gemini;

  List<SipTrunkConfig> get sipTrunks {
    return [
      SipTrunkConfig(
        id: trunkId,
        direction: SipTrunkDirection.bidirectional,
        serverUri: trunkServerUri,
        username: trunkUsername,
        password: trunkPassword,
        realm: trunkRealm,
      ),
    ];
  }

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
    media: SipMediaConfig(
      rtpStartPort: rtpStartPort,
      rtpEndPort: rtpEndPort,
      externalAddress: externalAddress,
    ),
    trunks: sipTrunks,
    features: const SipFeatureFlags(
      registrar: false,
      authentication: false,
      bridging: true,
      transfers: false,
      ivr: false,
      recording: false,
      voicemail: false,
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
