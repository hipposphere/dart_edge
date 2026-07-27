import 'sip_endpoint_config.dart';
import 'sip_engine_config.dart';
import 'sip_trunk_config.dart';

enum SipTransportProtocol {
  udp,
  tcp,
  tls;

  String get wireName => switch (this) {
    udp => 'udp',
    tcp => 'tcp',
    tls => 'tls',
  };
}

final class SipTransportBinding {
  const SipTransportBinding({
    required this.protocol,
    required this.host,
    required this.port,
    this.tlsProfile,
  });

  const SipTransportBinding.udp({required String host, required int port})
    : this(protocol: SipTransportProtocol.udp, host: host, port: port);

  const SipTransportBinding.tcp({required String host, required int port})
    : this(protocol: SipTransportProtocol.tcp, host: host, port: port);

  const SipTransportBinding.tls({
    required String host,
    required int port,
    String? tlsProfile,
  }) : this(
         protocol: SipTransportProtocol.tls,
         host: host,
         port: port,
         tlsProfile: tlsProfile,
       );

  final SipTransportProtocol protocol;
  final String host;
  final int port;
  final String? tlsProfile;

  Map<String, Object?> toJson() => {
    'protocol': protocol.wireName,
    'host': host,
    'port': port,
    'tlsProfile': ?tlsProfile,
  };
}

final class SipTlsProfile {
  const SipTlsProfile({
    required this.id,
    required this.certificatePath,
    required this.privateKeyPath,
    this.privateKeyPassword,
    this.caPath,
    this.verifyServer = true,
  });

  final String id;
  final String certificatePath;
  final String privateKeyPath;
  final String? privateKeyPassword;
  final String? caPath;
  final bool verifyServer;

  Map<String, Object?> toJson() => {
    'id': id,
    'certificatePath': certificatePath,
    'privateKeyPath': privateKeyPath,
    'privateKeyPassword': ?privateKeyPassword,
    'caPath': ?caPath,
    'verifyServer': verifyServer,
  };
}

final class SipRealmConfig {
  const SipRealmConfig({
    required this.domain,
    required this.realm,
    this.requireAuthentication = true,
  });

  final String domain;
  final String realm;
  final bool requireAuthentication;

  Map<String, Object?> toJson() => {
    'domain': domain,
    'realm': realm,
    'requireAuthentication': requireAuthentication,
  };
}

final class SipMediaConfig {
  const SipMediaConfig({
    this.rtpStartPort = 40000,
    this.rtpEndPort = 40100,
    this.externalAddress,
    this.enableSrtp = false,
    this.requireSrtp = false,
    this.enableDtmfDetection = true,
  });

  final int rtpStartPort;
  final int rtpEndPort;
  final String? externalAddress;
  final bool enableSrtp;
  final bool requireSrtp;
  final bool enableDtmfDetection;

  Map<String, Object?> toJson() => {
    'rtpStartPort': rtpStartPort,
    'rtpEndPort': rtpEndPort,
    'externalAddress': ?externalAddress,
    'enableSrtp': enableSrtp,
    'requireSrtp': requireSrtp,
    'enableDtmfDetection': enableDtmfDetection,
  };
}

final class SipRecordingStorageConfig {
  const SipRecordingStorageConfig({
    required this.enabled,
    this.directory,
    this.retentionDays,
  });

  const SipRecordingStorageConfig.disabled() : this(enabled: false);

  const SipRecordingStorageConfig.directory({
    required String directory,
    int? retentionDays,
  }) : this(enabled: true, directory: directory, retentionDays: retentionDays);

  final bool enabled;
  final String? directory;
  final int? retentionDays;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'directory': ?directory,
    'retentionDays': ?retentionDays,
  };
}

final class SipVoicemailStorageConfig {
  const SipVoicemailStorageConfig({
    required this.enabled,
    this.directory,
    this.defaultGreetingUri,
  });

  const SipVoicemailStorageConfig.disabled() : this(enabled: false);

  const SipVoicemailStorageConfig.directory({
    required String directory,
    String? defaultGreetingUri,
  }) : this(
         enabled: true,
         directory: directory,
         defaultGreetingUri: defaultGreetingUri,
       );

  final bool enabled;
  final String? directory;
  final String? defaultGreetingUri;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'directory': ?directory,
    'defaultGreetingUri': ?defaultGreetingUri,
  };
}

final class SipFeatureFlags {
  const SipFeatureFlags({
    this.registrar = true,
    this.authentication = true,
    this.bridging = true,
    this.transfers = true,
    this.ivr = true,
    this.recording = true,
    this.voicemail = true,
  });

  final bool registrar;
  final bool authentication;
  final bool bridging;
  final bool transfers;
  final bool ivr;
  final bool recording;
  final bool voicemail;

  Map<String, Object?> toJson() => {
    'registrar': registrar,
    'authentication': authentication,
    'bridging': bridging,
    'transfers': transfers,
    'ivr': ivr,
    'recording': recording,
    'voicemail': voicemail,
  };
}

final class SipServerConfig {
  const SipServerConfig({
    this.serverName = 'dart_edge_sip',
    this.engine = const PjsipEngineConfig(),
    this.transports = const <SipTransportBinding>[
      SipTransportBinding.udp(host: '0.0.0.0', port: 5060),
    ],
    this.tlsProfiles = const <SipTlsProfile>[],
    this.realms = const <SipRealmConfig>[],
    this.endpoints = const <SipEndpointConfig>[],
    this.trunks = const <SipTrunkConfig>[],
    this.media = const SipMediaConfig(),
    this.recordings = const SipRecordingStorageConfig.disabled(),
    this.voicemail = const SipVoicemailStorageConfig.disabled(),
    this.features = const SipFeatureFlags(),
  });

  final String serverName;
  final PjsipEngineConfig engine;
  final List<SipTransportBinding> transports;
  final List<SipTlsProfile> tlsProfiles;
  final List<SipRealmConfig> realms;
  final List<SipEndpointConfig> endpoints;
  final List<SipTrunkConfig> trunks;
  final SipMediaConfig media;
  final SipRecordingStorageConfig recordings;
  final SipVoicemailStorageConfig voicemail;
  final SipFeatureFlags features;

  Map<String, Object?> toJson() => {
    'serverName': serverName,
    'engine': engine.toJson(),
    'transports': transports.map((binding) => binding.toJson()).toList(),
    'tlsProfiles': tlsProfiles.map((profile) => profile.toJson()).toList(),
    'realms': realms.map((realm) => realm.toJson()).toList(),
    'endpoints': endpoints.map((endpoint) => endpoint.toJson()).toList(),
    'trunks': trunks.map((trunk) => trunk.toJson()).toList(),
    'media': media.toJson(),
    'recordings': recordings.toJson(),
    'voicemail': voicemail.toJson(),
    'features': features.toJson(),
  };
}
