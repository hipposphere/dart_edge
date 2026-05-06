import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';

import '../typed_bluetooth_application.dart';

void main() {
  emitBluetoothClient(
    onooSetupApplication,
    className: 'OnooSetupBluetoothClient',
  ).writeToDirectory('example/generated');

  emitBluetoothServerFacade(
    onooSetupApplication,
    className: 'OnooSetupBluetoothServer',
  ).writeToDirectory('example/generated');

  print('Typed Bluetooth client and server facades generated successfully.');
}
