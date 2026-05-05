import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';

import '../bluetooth_application.dart';

void main() {
  final emission = emitBluetoothServerFacade(
    environmentControlApplication,
    className: 'EnvironmentBluetoothServer',
  );
  emission.writeToDirectory('example/generated');
  print('Bluetooth server facade generated successfully.');
}
