final class BluetoothAdvertisementConfig {
  const BluetoothAdvertisementConfig({
    this.localName,
    this.discoverable = true,
    this.includePrimaryServiceUuids = true,
    this.manufacturerData = const <BluetoothManufacturerData>[],
    this.serviceData = const <BluetoothServiceData>[],
  });

  final String? localName;
  final bool discoverable;
  final bool includePrimaryServiceUuids;
  final List<BluetoothManufacturerData> manufacturerData;
  final List<BluetoothServiceData> serviceData;

  Map<String, Object?> toJson({required List<String> advertisedServiceUuids}) {
    return {
      if (localName case final localName?) 'localName': localName,
      'discoverable': discoverable,
      'serviceUuids': advertisedServiceUuids,
      if (manufacturerData.isNotEmpty)
        'manufacturerData': manufacturerData
            .map((entry) => entry.toJson())
            .toList(),
      if (serviceData.isNotEmpty)
        'serviceData': serviceData.map((entry) => entry.toJson()).toList(),
    };
  }
}

final class BluetoothManufacturerData {
  const BluetoothManufacturerData({
    required this.companyIdentifier,
    required this.data,
  });

  final int companyIdentifier;
  final List<int> data;

  Map<String, Object?> toJson() {
    return {'companyIdentifier': companyIdentifier, 'data': data};
  }
}

final class BluetoothServiceData {
  const BluetoothServiceData({required this.uuid, required this.data});

  final String uuid;
  final List<int> data;

  Map<String, Object?> toJson() {
    return {'uuid': uuid, 'data': data};
  }
}
