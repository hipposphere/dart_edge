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
    expect(source, contains("import 'dart:convert';"));
    expect(source, contains('final EnvironmentBluetoothClientRaw raw;'));
    expect(
      source,
      contains('final EnvironmentBluetoothClientControlService control;'),
    );
    expect(source, contains('final class EnvironmentBluetoothClientRaw'));
    expect(source, contains('Future<Uint8List> readControlStatus()'));
    expect(source, contains('Stream<Uint8List> watchControlStatus()'));
    expect(source, contains('Future<void> writeControlCommand'));
    expect(
      source,
      contains('Future<Uint8List> readControlStatusPresentationDescriptor()'),
    );
    expect(source, isNot(contains('writeControlStatus(')));
    expect(
      source,
      contains('final class EnvironmentBluetoothClientControlService'),
    );
    expect(
      source,
      contains('final EnvironmentBluetoothClientControlServiceRaw raw;'),
    );
    expect(source, contains('Future<String> readStatus() async'));
    expect(source, contains('Stream<String> watchStatus()'));
    expect(source, contains('Future<void> writeCommand('));
    expect(source, contains('String value'));
    expect(
      source,
      contains('final class EnvironmentBluetoothClientControlServiceRaw'),
    );
    expect(source, contains('Future<Uint8List> readStatus()'));
    expect(source, contains('Stream<Uint8List> watchStatus()'));
    expect(
      source,
      contains('Future<Uint8List> readStatusPresentationDescriptor()'),
    );
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
    expect(source, contains("import 'dart:convert';"));
    expect(source, contains('final EnvironmentBluetoothServerRaw raw;'));
    expect(
      source,
      contains('final EnvironmentBluetoothServerControlService control;'),
    );
    expect(source, contains('final class EnvironmentBluetoothServerRaw'));
    expect(source, contains('Future<void> setControlStatus'));
    expect(source, contains('Future<Uint8List> readControlStatus()'));
    expect(source, contains('controlStatusReadEvents'));
    expect(source, contains('controlCommandWriteEvents'));
    expect(source, contains('controlStatusSubscriptionEvents'));
    expect(
      source,
      contains('Future<Uint8List> readControlStatusPresentationDescriptor()'),
    );
    expect(
      source,
      contains('final class EnvironmentBluetoothServerControlService'),
    );
    expect(
      source,
      contains('final EnvironmentBluetoothServerControlServiceRaw raw;'),
    );
    expect(source, contains('Future<void> setStatus(String value'));
    expect(source, contains('Future<String> readStatus() async'));
    expect(source, contains('Stream<String> get commandWriteValues'));
    expect(
      source,
      contains('final class EnvironmentBluetoothServerControlServiceRaw'),
    );
    expect(source, contains('Future<void> setStatus(Uint8List value'));
    expect(source, contains('Future<Uint8List> readStatus()'));
    expect(source, contains('statusReadEvents'));
    expect(source, contains('commandWriteEvents'));
    expect(source, contains('statusSubscriptionEvents'));
    expect(
      source,
      contains('Future<Uint8List> readStatusPresentationDescriptor()'),
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
          codec: BluetoothGattValueCodecDefinition.utf8String(),
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
          codec: BluetoothGattValueCodecDefinition.utf8String(),
          write: BluetoothWriteAccess.requestsAndCommands(),
        ),
      ],
    ),
  ],
);
