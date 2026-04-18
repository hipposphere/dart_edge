enum SipEngineKind {
  pjsip;

  String get wireName => switch (this) {
    pjsip => 'pjsip',
  };
}

enum SipRuntimeLicenseMode {
  gpl,
  commercial;

  String get wireName => switch (this) {
    gpl => 'gpl',
    commercial => 'commercial',
  };
}

final class PjsipEngineConfig {
  const PjsipEngineConfig({
    this.licenseMode = SipRuntimeLicenseMode.gpl,
    this.maxCalls = 4,
    this.maxRegistrations = 5000,
    this.maxConferencePorts = 32,
    this.workerThreads = 2,
    this.enableIce = true,
    this.enableTurn = false,
    this.enableTls = true,
    this.enableSrtp = true,
    this.enableRport = true,
    this.userAgent = 'dart_edge_sip/0.1',
  });

  final SipRuntimeLicenseMode licenseMode;
  final int maxCalls;
  final int maxRegistrations;
  final int maxConferencePorts;
  final int workerThreads;
  final bool enableIce;
  final bool enableTurn;
  final bool enableTls;
  final bool enableSrtp;
  final bool enableRport;
  final String userAgent;

  Map<String, Object?> toJson() => {
    'kind': SipEngineKind.pjsip.wireName,
    'licenseMode': licenseMode.wireName,
    'maxCalls': maxCalls,
    'maxRegistrations': maxRegistrations,
    'maxConferencePorts': maxConferencePorts,
    'workerThreads': workerThreads,
    'enableIce': enableIce,
    'enableTurn': enableTurn,
    'enableTls': enableTls,
    'enableSrtp': enableSrtp,
    'enableRport': enableRport,
    'userAgent': userAgent,
  };
}
