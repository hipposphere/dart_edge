/// Request for connecting to a Wi-Fi network.
final class WifiConnectionRequest {
  const WifiConnectionRequest({
    required this.ssid,
    this.password,
    this.interfaceName,
    this.bssid,
    this.connectionName,
    this.hidden = false,
  });

  /// Network name to connect to.
  final String ssid;

  /// Password for secured networks. Leave null for open networks.
  final String? password;

  /// Optional Linux Wi-Fi interface name, for example `wlan0`.
  final String? interfaceName;

  /// Optional access point BSSID to force a specific AP.
  final String? bssid;

  /// Optional NetworkManager connection profile name.
  final String? connectionName;

  /// Whether this is a hidden SSID.
  final bool hidden;

  Map<String, Object?> toJson() {
    return {
      'ssid': ssid,
      'password': password,
      'interfaceName': interfaceName,
      'bssid': bssid,
      'connectionName': connectionName,
      'hidden': hidden,
    };
  }
}
