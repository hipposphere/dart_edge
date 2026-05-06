import 'bluetooth_gatt_access.dart';
import 'bluetooth_gatt_descriptor_definition.dart';
import 'bluetooth_gatt_value_codec_definition.dart';

final class BluetoothGattCharacteristicDefinition {
  const BluetoothGattCharacteristicDefinition({
    required this.id,
    required this.uuid,
    this.initialValue = const <int>[],
    this.broadcast = false,
    this.writableAuxiliaries = false,
    this.authorize = false,
    this.read = const BluetoothReadAccess(),
    this.write = const BluetoothWriteAccess(),
    this.notify = const BluetoothNotifyAccess(),
    this.codec,
    this.descriptors = const <BluetoothGattDescriptorDefinition>[],
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String uuid;
  final List<int> initialValue;
  final bool broadcast;
  final bool writableAuxiliaries;
  final bool authorize;
  final BluetoothReadAccess read;
  final BluetoothWriteAccess write;
  final BluetoothNotifyAccess notify;
  final BluetoothGattValueCodecDefinition? codec;
  final List<BluetoothGattDescriptorDefinition> descriptors;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'initialValue': initialValue,
      'broadcast': broadcast,
      'writableAuxiliaries': writableAuxiliaries,
      'authorize': authorize,
      'read': read.toJson(),
      'write': write.toJson(),
      'notify': notify.toJson(),
      'descriptors': descriptors.map((entry) => entry.toJson()).toList(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
