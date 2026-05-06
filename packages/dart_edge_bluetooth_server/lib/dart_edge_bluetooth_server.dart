/// Standalone Bluetooth GATT server package for Dart Edge.
///
/// Import this library to declare reusable GATT application definitions and
/// serve them through a native Linux/BlueZ backend.
library;

export 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';

export 'src/config/bluetooth_advertisement_config.dart';
export 'src/config/bluetooth_server_config.dart';
export 'src/events/bluetooth_server_event.dart';
export 'src/runtime/dart_edge_bluetooth_server.dart';
