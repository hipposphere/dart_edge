import 'dart:io';

import 'backends/core_wlan_wifi_backend.dart';
import 'backends/nmcli_wifi_backend.dart';
import 'backends/unsupported_wifi_backend.dart';
import 'wifi_backend.dart';
import 'wifi_connection_request.dart';
import 'wifi_connection_result.dart';
import 'wifi_network.dart';
import 'wifi_rescan_policy.dart';

/// Platform Wi-Fi client for Dart Edge.
final class DartEdgeWifi implements WifiBackend {
  DartEdgeWifi({WifiBackend? backend})
    : _backend = backend ?? _defaultBackend();

  final WifiBackend _backend;

  @override
  Future<List<WifiNetwork>> listNetworks({
    String? interfaceName,
    WifiRescanPolicy rescan = WifiRescanPolicy.auto,
  }) {
    return _backend.listNetworks(interfaceName: interfaceName, rescan: rescan);
  }

  @override
  Future<WifiConnectionResult> connect(WifiConnectionRequest request) {
    return _backend.connect(request);
  }

  static WifiBackend _defaultBackend() {
    if (Platform.isLinux) {
      return const NmcliWifiBackend();
    }
    if (Platform.isMacOS) {
      return const CoreWlanWifiBackend();
    }
    return UnsupportedWifiBackend(Platform.operatingSystem);
  }
}
