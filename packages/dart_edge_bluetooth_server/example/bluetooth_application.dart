import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';

const environmentControlApplication = BluetoothGattApplication(
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
);
