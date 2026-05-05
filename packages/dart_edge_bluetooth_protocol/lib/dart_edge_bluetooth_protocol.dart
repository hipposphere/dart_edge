/// Bluetooth GATT protocol contracts and explicit code emitters for Dart Edge.
///
/// Import this library to define reusable GATT applications, implement a
/// platform-specific client backend, and emit typed client/server facades from
/// normal Dart tool scripts.
library dart_edge_bluetooth_protocol;

export 'src/client/bluetooth_client_backend.dart';
export 'src/codegen/bluetooth_code_emitter.dart';
export 'src/gatt/bluetooth_gatt_access.dart';
export 'src/gatt/bluetooth_gatt_application.dart';
export 'src/gatt/bluetooth_gatt_characteristic_definition.dart';
export 'src/gatt/bluetooth_gatt_descriptor_definition.dart';
export 'src/gatt/bluetooth_gatt_path.dart';
export 'src/gatt/bluetooth_gatt_service_definition.dart';
