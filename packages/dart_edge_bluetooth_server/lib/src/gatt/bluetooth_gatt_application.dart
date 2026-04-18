import 'bluetooth_gatt_service_definition.dart';

final class BluetoothGattApplication {
  const BluetoothGattApplication({
    required this.services,
    this.metadata = const <String, Object?>{},
  });

  final List<BluetoothGattServiceDefinition> services;
  final Map<String, Object?> metadata;

  List<String> get primaryServiceUuids {
    return services
        .where((service) => service.primary)
        .map((service) => service.uuid)
        .toList(growable: false);
  }

  Map<String, Object?> toJson() {
    return {
      'services': services.map((service) => service.toJson()).toList(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
