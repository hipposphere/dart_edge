import 'bluetooth_gatt_access.dart';

final class BluetoothGattDescriptorDefinition {
  const BluetoothGattDescriptorDefinition({
    required this.id,
    required this.uuid,
    this.initialValue = const <int>[],
    this.authorize = false,
    this.read = const BluetoothReadAccess(),
    this.write = const BluetoothWriteAccess(),
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String uuid;
  final List<int> initialValue;
  final bool authorize;
  final BluetoothReadAccess read;
  final BluetoothWriteAccess write;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'initialValue': initialValue,
      'authorize': authorize,
      'read': read.toJson(),
      'write': write.toJson(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
