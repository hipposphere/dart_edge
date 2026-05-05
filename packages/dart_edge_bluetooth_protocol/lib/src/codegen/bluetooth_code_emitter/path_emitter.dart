part of '../bluetooth_code_emitter.dart';

void _emitPathConstants(StringBuffer buffer, BluetoothGattApplication app) {
  for (final entry in _characteristics(app)) {
    buffer
      ..writeln(
        'static const ${entry.pathName} = BluetoothGattCharacteristicPath(',
      )
      ..writeln("serviceId: '${_escape(entry.service.id)}',")
      ..writeln("characteristicId: '${_escape(entry.characteristic.id)}',")
      ..writeln(');')
      ..writeln();

    for (final descriptor in entry.characteristic.descriptors) {
      final descriptorName = _descriptorPathName(entry, descriptor);
      buffer
        ..writeln('static const $descriptorName = BluetoothGattDescriptorPath(')
        ..writeln("serviceId: '${_escape(entry.service.id)}',")
        ..writeln("characteristicId: '${_escape(entry.characteristic.id)}',")
        ..writeln("descriptorId: '${_escape(descriptor.id)}',")
        ..writeln(');')
        ..writeln();
    }
  }
}
