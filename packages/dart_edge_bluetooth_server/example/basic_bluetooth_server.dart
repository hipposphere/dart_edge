import 'dart:async';
import 'dart:typed_data';

import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';

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
      application: const BluetoothGattApplication(
        services: [
          BluetoothGattServiceDefinition(
            id: 'control',
            uuid: '12345678-1234-5678-1234-56789abcdef0',
            characteristics: [
              BluetoothGattCharacteristicDefinition(
                id: 'status',
                uuid: '12345678-1234-5678-1234-56789abcdef1',
                initialValue: [0],
                read: BluetoothReadAccess.enabled(),
                notify: BluetoothNotifyAccess.notify(),
              ),
              BluetoothGattCharacteristicDefinition(
                id: 'command',
                uuid: '12345678-1234-5678-1234-56789abcdef2',
                write: BluetoothWriteAccess.requestsAndCommands(),
              ),
            ],
          ),
        ],
      ),
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
