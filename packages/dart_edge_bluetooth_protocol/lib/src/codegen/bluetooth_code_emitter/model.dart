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

List<_CharacteristicEntry> _serviceCharacteristics(
  BluetoothGattServiceDefinition service,
) {
  final entries = <_CharacteristicEntry>[];
  final usedMemberNames = <String, int>{};
  final usedPathNames = <String, int>{};

  for (final characteristic in service.characteristics) {
    final baseMemberName = _pascalCase(characteristic.id);
    final basePathName = '${_camelCase(characteristic.id)}Path';
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

  return entries;
}

List<_ServiceEntry> _services(BluetoothGattApplication app, String facadeName) {
  final entries = <_ServiceEntry>[];
  final usedMemberNames = <String, int>{};
  final usedClassNames = <String, int>{};

  for (final service in app.services) {
    final baseMemberName = _camelCase(service.id);
    final baseClassName = '$facadeName${_pascalCase(service.id)}Service';
    final memberName = _dedupe(baseMemberName, usedMemberNames);
    final className = _dedupe(baseClassName, usedClassNames);
    entries.add(
      _ServiceEntry(
        service: service,
        memberName: memberName,
        className: className,
      ),
    );
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

final class _ServiceEntry {
  const _ServiceEntry({
    required this.service,
    required this.memberName,
    required this.className,
  });

  final BluetoothGattServiceDefinition service;
  final String memberName;
  final String className;
}

Iterable<BluetoothGattValueCodecDefinition> _codecs(
  BluetoothGattApplication app,
) sync* {
  for (final entry in _characteristics(app)) {
    if (entry.characteristic.codec case final codec?) {
      yield codec;
    }
    for (final descriptor in entry.characteristic.descriptors) {
      if (descriptor.codec case final codec?) {
        yield codec;
      }
    }
  }
}

Iterable<Directive> _dartImports(
  BluetoothGattApplication app,
  Iterable<String> baseImports,
) {
  return SplayTreeSet<String>.of([
    ...baseImports,
    ..._codecImportUris(app).where((uri) => uri.startsWith('dart:')),
  ]).map((uri) => Directive.import(uri));
}

Iterable<Directive> _codecPackageImports(BluetoothGattApplication app) {
  return _codecImportUris(app)
      .where((uri) => uri.startsWith('package:'))
      .map((uri) => Directive.import(uri));
}

Iterable<Directive> _codecRelativeImports(BluetoothGattApplication app) {
  return _codecImportUris(app)
      .where((uri) => !uri.startsWith('dart:') && !uri.startsWith('package:'))
      .map((uri) => Directive.import(uri));
}

Set<String> _codecImportUris(BluetoothGattApplication app) {
  return SplayTreeSet<String>.of(
    _codecs(app).expand<String>((codec) => codec.imports),
  );
}
