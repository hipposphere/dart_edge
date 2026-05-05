import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('emits client helpers from characteristic capabilities', () {
    final emission = emitBluetoothClient(
      _application,
      className: 'EnvironmentBluetoothClient',
    );
    final source = emission
        .fileAt('environment_bluetooth_client.g.dart')
        .contents;

    expect(source, contains('final class EnvironmentBluetoothClient'));
    expect(source, contains('Future<Uint8List> readControlStatus()'));
    expect(source, contains('Stream<Uint8List> watchControlStatus()'));
    expect(source, contains('Future<void> writeControlCommand'));
    expect(
      source,
      contains('Future<Uint8List> readControlStatusPresentationDescriptor()'),
    );
    expect(source, isNot(contains('writeControlStatus(')));
  });

  test('emits server facade helpers from characteristic capabilities', () {
    final emission = emitBluetoothServerFacade(
      _application,
      className: 'EnvironmentBluetoothServer',
    );
    final source = emission
        .fileAt('environment_bluetooth_server.g.dart')
        .contents;

    expect(source, contains('final class EnvironmentBluetoothServer'));
    expect(source, contains('final DartEdgeBluetoothServer server;'));
    expect(source, contains('Future<void> setControlStatus'));
    expect(source, contains('Future<Uint8List> readControlStatus()'));
    expect(source, contains('controlStatusReadEvents'));
    expect(source, contains('controlCommandWriteEvents'));
    expect(source, contains('controlStatusSubscriptionEvents'));
    expect(
      source,
      contains('Future<Uint8List> readControlStatusPresentationDescriptor()'),
    );
  });
}

const _application = BluetoothGattApplication(
  services: [
    BluetoothGattServiceDefinition(
      id: 'control',
      uuid: '12345678-1234-5678-1234-56789abcdef0',
      characteristics: [
        BluetoothGattCharacteristicDefinition(
          id: 'status',
          uuid: '12345678-1234-5678-1234-56789abcdef1',
          read: BluetoothReadAccess.enabled(),
          notify: BluetoothNotifyAccess.notify(),
          descriptors: [
            BluetoothGattDescriptorDefinition(
              id: 'presentation',
              uuid: '2904',
              read: BluetoothReadAccess.enabled(),
            ),
          ],
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
