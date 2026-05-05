import 'dart:async';
import 'dart:typed_data';

import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';

import 'bluetooth_application.dart';

Future<void> main() async {
  if (!DartEdgeBluetoothServer.isSupportedPlatform) {
    print(
      'This example requires Linux with BlueZ because the native backend uses bluer.',
    );
    return;
  }

  const statusPath = BluetoothGattCharacteristicPath(
    serviceId: 'control',
    characteristicId: 'status',
  );

  final server = DartEdgeBluetoothServer(
    config: BluetoothServerConfig(
      serverName: 'environment-control',
      advertisement: const BluetoothAdvertisementConfig(
        localName: 'Dart Edge BLE',
      ),
      application: environmentControlApplication,
    ),
  );

  final subscription = server.events.listen((event) {
    print('Bluetooth event: $event');
  });

  await server.start();
  await server.setCharacteristicValue(
    statusPath,
    Uint8List.fromList([1]),
    notify: true,
  );

  await Future<void>.delayed(const Duration(seconds: 30));
  await subscription.cancel();
  await server.dispose();
}
