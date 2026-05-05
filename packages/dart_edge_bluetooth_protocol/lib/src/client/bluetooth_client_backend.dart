import 'dart:typed_data';

import '../gatt/bluetooth_gatt_path.dart';

/// Platform-specific backend used by generated Bluetooth clients.
///
/// Implementations can wrap Flutter BLE libraries such as `flutter_blue_plus`,
/// native desktop APIs, or test fakes. Dart Edge intentionally keeps those
/// dependencies outside this protocol package.
abstract interface class BluetoothClientBackend {
  Future<void> connect();

  Future<void> disconnect();

  Future<Uint8List> readCharacteristic(BluetoothGattCharacteristicPath path);

  Future<void> writeCharacteristic(
    BluetoothGattCharacteristicPath path,
    Uint8List value, {
    bool withoutResponse = false,
  });

  Stream<Uint8List> subscribeToCharacteristic(
    BluetoothGattCharacteristicPath path,
  );

  Future<Uint8List> readDescriptor(BluetoothGattDescriptorPath path);

  Future<void> writeDescriptor(
    BluetoothGattDescriptorPath path,
    Uint8List value,
  );
}
