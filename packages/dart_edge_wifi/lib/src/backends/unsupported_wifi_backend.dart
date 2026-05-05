import '../wifi_backend.dart';
import '../wifi_connection_request.dart';
import '../wifi_connection_result.dart';
import '../wifi_network.dart';
import '../wifi_rescan_policy.dart';

final class UnsupportedWifiBackend implements WifiBackend {
  const UnsupportedWifiBackend(this.platformName);

  final String platformName;

  @override
  Future<List<WifiNetwork>> listNetworks({
    String? interfaceName,
    WifiRescanPolicy rescan = WifiRescanPolicy.auto,
  }) {
    throw UnsupportedError(
      'dart_edge_wifi does not support Wi-Fi scanning on $platformName.',
    );
  }

  @override
  Future<WifiConnectionResult> connect(WifiConnectionRequest request) {
    throw UnsupportedError(
      'dart_edge_wifi does not support Wi-Fi connection on $platformName.',
    );
  }
}
