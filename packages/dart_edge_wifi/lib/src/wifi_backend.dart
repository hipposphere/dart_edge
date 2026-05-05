import 'wifi_connection_request.dart';
import 'wifi_connection_result.dart';
import 'wifi_network.dart';
import 'wifi_rescan_policy.dart';

/// Platform backend used by [DartEdgeWifi].
abstract interface class WifiBackend {
  Future<List<WifiNetwork>> listNetworks({
    String? interfaceName,
    WifiRescanPolicy rescan = WifiRescanPolicy.auto,
  });

  Future<WifiConnectionResult> connect(WifiConnectionRequest request);
}
