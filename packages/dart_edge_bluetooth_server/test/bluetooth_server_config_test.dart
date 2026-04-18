import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';
import 'package:test/test.dart';

void main() {
  test('serializes GATT definitions and advertisement config', () {
    const config = BluetoothServerConfig(
      serverName: 'test-server',
      adapterName: 'hci1',
      advertisement: BluetoothAdvertisementConfig(
        localName: 'Dart Edge BLE',
        manufacturerData: [
          BluetoothManufacturerData(companyIdentifier: 0x1234, data: [1, 2, 3]),
        ],
        serviceData: [
          BluetoothServiceData(
            uuid: '12345678-1234-5678-1234-56789abcdef0',
            data: [9, 8, 7],
          ),
        ],
      ),
      application: BluetoothGattApplication(
        services: [
          BluetoothGattServiceDefinition(
            id: 'control',
            uuid: '12345678-1234-5678-1234-56789abcdef0',
            characteristics: [
              BluetoothGattCharacteristicDefinition(
                id: 'status',
                uuid: '12345678-1234-5678-1234-56789abcdef1',
                initialValue: [1],
                read: BluetoothReadAccess.enabled(),
                notify: BluetoothNotifyAccess.notify(),
                descriptors: [
                  BluetoothGattDescriptorDefinition(
                    id: 'presentation',
                    uuid: '2904',
                    initialValue: [4, 0],
                    read: BluetoothReadAccess.enabled(),
                  ),
                ],
              ),
              BluetoothGattCharacteristicDefinition(
                id: 'command',
                uuid: '12345678-1234-5678-1234-56789abcdef2',
                write: BluetoothWriteAccess.requestsAndCommands(
                  notifySubscribersOnWrite: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    expect(config.toJson(), {
      'serverName': 'test-server',
      'adapterName': 'hci1',
      'autoPowerAdapter': true,
      'advertisement': {
        'localName': 'Dart Edge BLE',
        'discoverable': true,
        'serviceUuids': ['12345678-1234-5678-1234-56789abcdef0'],
        'manufacturerData': [
          {
            'companyIdentifier': 0x1234,
            'data': [1, 2, 3],
          },
        ],
        'serviceData': [
          {
            'uuid': '12345678-1234-5678-1234-56789abcdef0',
            'data': [9, 8, 7],
          },
        ],
      },
      'application': {
        'services': [
          {
            'id': 'control',
            'uuid': '12345678-1234-5678-1234-56789abcdef0',
            'primary': true,
            'characteristics': [
              {
                'id': 'status',
                'uuid': '12345678-1234-5678-1234-56789abcdef1',
                'initialValue': [1],
                'broadcast': false,
                'writableAuxiliaries': false,
                'authorize': false,
                'read': {
                  'enabled': true,
                  'requiresEncryption': false,
                  'requiresAuthentication': false,
                  'requiresSecureConnection': false,
                  'emitReadEvents': true,
                },
                'write': {
                  'allowWriteRequest': false,
                  'allowWriteCommand': false,
                  'allowReliableWrite': false,
                  'allowAuthenticatedSignedWrite': false,
                  'requiresEncryption': false,
                  'requiresAuthentication': false,
                  'requiresSecureConnection': false,
                  'persistWrittenValue': true,
                  'emitWriteEvents': true,
                  'notifySubscribersOnWrite': false,
                },
                'notify': {
                  'enabled': true,
                  'indicate': false,
                  'emitSubscriptionEvents': true,
                },
                'descriptors': [
                  {
                    'id': 'presentation',
                    'uuid': '2904',
                    'initialValue': [4, 0],
                    'authorize': false,
                    'read': {
                      'enabled': true,
                      'requiresEncryption': false,
                      'requiresAuthentication': false,
                      'requiresSecureConnection': false,
                      'emitReadEvents': true,
                    },
                    'write': {
                      'allowWriteRequest': false,
                      'allowWriteCommand': false,
                      'allowReliableWrite': false,
                      'allowAuthenticatedSignedWrite': false,
                      'requiresEncryption': false,
                      'requiresAuthentication': false,
                      'requiresSecureConnection': false,
                      'persistWrittenValue': true,
                      'emitWriteEvents': true,
                      'notifySubscribersOnWrite': false,
                    },
                  },
                ],
              },
              {
                'id': 'command',
                'uuid': '12345678-1234-5678-1234-56789abcdef2',
                'initialValue': <int>[],
                'broadcast': false,
                'writableAuxiliaries': false,
                'authorize': false,
                'read': {
                  'enabled': false,
                  'requiresEncryption': false,
                  'requiresAuthentication': false,
                  'requiresSecureConnection': false,
                  'emitReadEvents': true,
                },
                'write': {
                  'allowWriteRequest': true,
                  'allowWriteCommand': true,
                  'allowReliableWrite': false,
                  'allowAuthenticatedSignedWrite': false,
                  'requiresEncryption': false,
                  'requiresAuthentication': false,
                  'requiresSecureConnection': false,
                  'persistWrittenValue': true,
                  'emitWriteEvents': true,
                  'notifySubscribersOnWrite': true,
                },
                'notify': {
                  'enabled': false,
                  'indicate': false,
                  'emitSubscriptionEvents': true,
                },
                'descriptors': <Map<String, Object?>>[],
              },
            ],
          },
        ],
      },
    });
  });
}
