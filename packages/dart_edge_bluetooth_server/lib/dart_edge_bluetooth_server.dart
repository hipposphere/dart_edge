/// Standalone Bluetooth GATT server package for Dart Edge.
///
/// Import this library to declare reusable GATT application definitions and
/// serve them through a native Linux/BlueZ backend.
library dart_edge_bluetooth_server;

export 'src/config/bluetooth_advertisement_config.dart';
export 'src/config/bluetooth_server_config.dart';
export 'src/events/bluetooth_server_event.dart';
export 'src/gatt/bluetooth_gatt_access.dart';
export 'src/gatt/bluetooth_gatt_application.dart';
export 'src/gatt/bluetooth_gatt_characteristic_definition.dart';
export 'src/gatt/bluetooth_gatt_descriptor_definition.dart';
export 'src/gatt/bluetooth_gatt_path.dart';
export 'src/gatt/bluetooth_gatt_service_definition.dart';
export 'src/runtime/dart_edge_bluetooth_server.dart';
