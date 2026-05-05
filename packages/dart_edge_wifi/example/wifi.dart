import 'package:dart_edge_wifi/dart_edge_wifi.dart';

Future<void> main() async {
  final wifi = DartEdgeWifi();
  final networks = await wifi.listNetworks();

  for (final network in networks) {
    final ssid = network.ssid.isEmpty ? '<ssid unavailable>' : network.ssid;
    final security = network.isSecured ? network.security : 'open';
    final signal = network.signalPercent == null
        ? 'unknown signal'
        : '${network.signalPercent}%';
    print('$ssid ($signal, $security)');
  }
}
