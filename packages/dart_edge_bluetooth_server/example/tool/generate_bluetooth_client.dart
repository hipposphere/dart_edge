import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';

import '../bluetooth_application.dart';

void main() {
  final emission = emitBluetoothClient(
    environmentControlApplication,
    className: 'EnvironmentBluetoothClient',
  );
  emission.writeToDirectory('example/generated');
  print('Bluetooth client generated successfully.');
}
