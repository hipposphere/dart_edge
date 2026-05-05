# dart_edge_wifi

Wi-Fi network discovery and connection helpers for Dart Edge.

Supported backends:

- Linux: NetworkManager's `nmcli`
- macOS: CoreWLAN through Dart Objective-C interop

```dart
import 'package:dart_edge_wifi/dart_edge_wifi.dart';

Future<void> main() async {
  const wifi = DartEdgeWifi();

  final networks = await wifi.listNetworks();
  for (final network in networks) {
    print('${network.ssid} ${network.signalPercent}% ${network.security}');
  }

  await wifi.connect(
    const WifiConnectionRequest(
      ssid: 'office',
      password: 'correct horse battery staple',
    ),
  );
}
```

The process running the Dart application must have permission to scan for and
connect to Wi-Fi networks through the host platform.

On macOS, CoreWLAN scan results may omit SSID and BSSID values unless Location
Services is enabled and the running app or terminal has location permission. For
local CLI development, grant Location Services access to the terminal app that
runs Dart, such as Terminal, iTerm, or VS Code, then restart that app.
