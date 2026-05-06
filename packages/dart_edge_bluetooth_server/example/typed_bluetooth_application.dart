import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';

const onooSetupApplication = BluetoothGattApplication(
  services: [
    BluetoothGattServiceDefinition(
      id: 'device_info',
      uuid: '8f4a0000-7d6a-4c1f-9f5d-6a7d5f2a0000',
      characteristics: [
        BluetoothGattCharacteristicDefinition(
          id: 'firmware_version',
          uuid: '8f4a0001-7d6a-4c1f-9f5d-6a7d5f2a0000',
          codec: BluetoothGattValueCodecDefinition.utf8String(),
          read: BluetoothReadAccess.enabled(),
          notify: BluetoothNotifyAccess.notify(),
        ),
      ],
    ),
    BluetoothGattServiceDefinition(
      id: 'wifi',
      uuid: '8f4a1000-7d6a-4c1f-9f5d-6a7d5f2a0000',
      characteristics: [
        BluetoothGattCharacteristicDefinition(
          id: 'command',
          uuid: '8f4a1001-7d6a-4c1f-9f5d-6a7d5f2a0000',
          codec: BluetoothGattValueCodecDefinition(
            dartType: 'OnooBluetoothRequest',
            encodeExpression:
                'Uint8List.fromList(utf8.encode(jsonEncode(value.toJson())))',
            decodeExpression:
                'OnooBluetoothRequest.fromJson(jsonDecode(utf8.decode(value)) as Map<String, Object?>)',
            imports: ['dart:convert', '../typed_bluetooth_models.dart'],
          ),
          write: BluetoothWriteAccess.requestsAndCommands(),
        ),
        BluetoothGattCharacteristicDefinition(
          id: 'response',
          uuid: '8f4a1002-7d6a-4c1f-9f5d-6a7d5f2a0000',
          codec: BluetoothGattValueCodecDefinition(
            dartType: 'OnooBluetoothResponse',
            encodeExpression:
                'Uint8List.fromList(utf8.encode(jsonEncode(value.toJson())))',
            decodeExpression:
                'OnooBluetoothResponse.fromJson(jsonDecode(utf8.decode(value)) as Map<String, Object?>)',
            imports: ['dart:convert', '../typed_bluetooth_models.dart'],
          ),
          read: BluetoothReadAccess.enabled(),
          notify: BluetoothNotifyAccess.notify(),
        ),
        BluetoothGattCharacteristicDefinition(
          id: 'state',
          uuid: '8f4a1003-7d6a-4c1f-9f5d-6a7d5f2a0000',
          codec: BluetoothGattValueCodecDefinition(
            dartType: 'OnooWifiState',
            encodeExpression:
                'Uint8List.fromList(utf8.encode(jsonEncode(value.toJson())))',
            decodeExpression:
                'OnooWifiState.fromJson(jsonDecode(utf8.decode(value)) as Map<String, Object?>)',
            imports: ['dart:convert', '../typed_bluetooth_models.dart'],
          ),
          read: BluetoothReadAccess.enabled(),
          notify: BluetoothNotifyAccess.notify(),
        ),
      ],
    ),
  ],
);
