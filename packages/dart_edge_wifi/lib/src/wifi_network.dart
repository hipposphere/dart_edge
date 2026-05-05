/// A Wi-Fi network reported by NetworkManager.
final class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.channel,
    required this.frequencyMHz,
    required this.signalPercent,
    required this.rssiDbm,
    required this.security,
    required this.inUse,
    required this.mode,
  });

  /// Network name. Hidden networks can report an empty SSID.
  final String ssid;
  final String? bssid;
  final int? channel;
  final int? frequencyMHz;
  final int? signalPercent;
  final int? rssiDbm;
  final String security;
  final bool inUse;
  final String mode;

  bool get isSecured => security.isNotEmpty && security != '--';

  factory WifiNetwork.fromJson(Map<String, Object?> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String? ?? '',
      bssid: json['bssid'] as String?,
      channel: json['channel'] as int?,
      frequencyMHz: json['frequencyMHz'] as int?,
      signalPercent: json['signalPercent'] as int?,
      rssiDbm: json['rssiDbm'] as int?,
      security: json['security'] as String? ?? '',
      inUse: json['inUse'] as bool? ?? false,
      mode: json['mode'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'WifiNetwork('
        'ssid: $ssid, '
        'bssid: $bssid, '
        'channel: $channel, '
        'frequencyMHz: $frequencyMHz, '
        'signalPercent: $signalPercent, '
        'rssiDbm: $rssiDbm, '
        'security: $security, '
        'inUse: $inUse, '
        'mode: $mode'
        ')';
  }
}
