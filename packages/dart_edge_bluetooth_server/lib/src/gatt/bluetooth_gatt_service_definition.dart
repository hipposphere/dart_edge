import 'bluetooth_gatt_characteristic_definition.dart';

final class BluetoothGattServiceDefinition {
  const BluetoothGattServiceDefinition({
    required this.id,
    required this.uuid,
    this.primary = true,
    this.characteristics = const <BluetoothGattCharacteristicDefinition>[],
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String uuid;
  final bool primary;
  final List<BluetoothGattCharacteristicDefinition> characteristics;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'primary': primary,
      'characteristics': characteristics
          .map((entry) => entry.toJson())
          .toList(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
