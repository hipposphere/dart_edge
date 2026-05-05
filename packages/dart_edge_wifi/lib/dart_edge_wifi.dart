/// Linux and macOS Wi-Fi network discovery and connection helpers for Dart Edge.
///
/// Import this library to scan for nearby networks and connect through the
/// host platform's Wi-Fi backend.
library dart_edge_wifi;

export 'src/backends/core_wlan_wifi_backend.dart';
export 'src/backends/nmcli_wifi_backend.dart';
export 'src/dart_edge_wifi.dart';
export 'src/wifi_backend.dart';
export 'src/wifi_command_result.dart';
export 'src/wifi_connection_request.dart';
export 'src/wifi_connection_result.dart';
export 'src/wifi_exception.dart';
export 'src/wifi_network.dart';
export 'src/wifi_rescan_policy.dart';
