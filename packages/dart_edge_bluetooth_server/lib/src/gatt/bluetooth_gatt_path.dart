final class BluetoothGattCharacteristicPath {
  const BluetoothGattCharacteristicPath({
    required this.serviceId,
    required this.characteristicId,
  });

  final String serviceId;
  final String characteristicId;

  factory BluetoothGattCharacteristicPath.fromJson(Map<String, Object?> json) {
    return BluetoothGattCharacteristicPath(
      serviceId: json['serviceId'] as String,
      characteristicId: json['characteristicId'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {'serviceId': serviceId, 'characteristicId': characteristicId};
  }
}

final class BluetoothGattDescriptorPath {
  const BluetoothGattDescriptorPath({
    required this.serviceId,
    required this.characteristicId,
    required this.descriptorId,
  });

  final String serviceId;
  final String characteristicId;
  final String descriptorId;

  factory BluetoothGattDescriptorPath.fromJson(Map<String, Object?> json) {
    return BluetoothGattDescriptorPath(
      serviceId: json['serviceId'] as String,
      characteristicId: json['characteristicId'] as String,
      descriptorId: json['descriptorId'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'serviceId': serviceId,
      'characteristicId': characteristicId,
      'descriptorId': descriptorId,
    };
  }
}
