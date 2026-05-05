part of '../bluetooth_code_emitter.dart';

List<_CharacteristicEntry> _characteristics(BluetoothGattApplication app) {
  final entries = <_CharacteristicEntry>[];
  final usedMemberNames = <String, int>{};
  final usedPathNames = <String, int>{};

  for (final service in app.services) {
    for (final characteristic in service.characteristics) {
      final baseMemberName =
          '${_pascalCase(service.id)}${_pascalCase(characteristic.id)}';
      final basePathName =
          '${_camelCase(service.id)}${_pascalCase(characteristic.id)}Path';
      final memberName = _dedupe(baseMemberName, usedMemberNames);
      final pathName = _dedupe(basePathName, usedPathNames);
      entries.add(
        _CharacteristicEntry(
          service: service,
          characteristic: characteristic,
          memberName: memberName,
          pathName: pathName,
        ),
      );
    }
  }

  return entries;
}

final class _CharacteristicEntry {
  const _CharacteristicEntry({
    required this.service,
    required this.characteristic,
    required this.memberName,
    required this.pathName,
  });

  final BluetoothGattServiceDefinition service;
  final BluetoothGattCharacteristicDefinition characteristic;
  final String memberName;
  final String pathName;
}
