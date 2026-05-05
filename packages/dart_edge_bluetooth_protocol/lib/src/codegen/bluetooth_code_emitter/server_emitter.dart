part of '../bluetooth_code_emitter.dart';

String _emitServerLibrary(
  BluetoothGattApplication application, {
  required String className,
}) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln()
    ..writeln("import 'dart:async';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln(
      "import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';",
    )
    ..writeln()
    ..writeln('final class $className {')
    ..writeln('const $className(this.server);')
    ..writeln()
    ..writeln('final DartEdgeBluetoothServer server;')
    ..writeln();

  _emitPathConstants(buffer, application);
  _emitServerMembers(buffer, application);

  buffer.writeln('}');
  return buffer.toString();
}

void _emitServerMembers(StringBuffer buffer, BluetoothGattApplication app) {
  for (final entry in _characteristics(app)) {
    final baseName = entry.memberName;
    final pathName = entry.pathName;
    final characteristic = entry.characteristic;

    buffer
      ..writeln(
        'Future<void> set$baseName(Uint8List value, {bool notify = false}) {',
      )
      ..writeln(
        'return server.setCharacteristicValue($pathName, value, notify: notify);',
      )
      ..writeln('}')
      ..writeln();

    if (characteristic.read.enabled) {
      buffer
        ..writeln('Future<Uint8List> read$baseName() {')
        ..writeln('return server.readCharacteristicValue($pathName);')
        ..writeln('}')
        ..writeln()
        ..writeln(
          'Stream<BluetoothCharacteristicReadEvent> get ${_lowerFirst(baseName)}ReadEvents {',
        )
        ..writeln(
          'return server.characteristicReadEvents.where((event) => _is${baseName}Path(event.path));',
        )
        ..writeln('}')
        ..writeln();
    }

    if (characteristic.write.enabled) {
      buffer
        ..writeln(
          'Stream<BluetoothCharacteristicWriteEvent> get ${_lowerFirst(baseName)}WriteEvents {',
        )
        ..writeln(
          'return server.characteristicWriteEvents.where((event) => _is${baseName}Path(event.path));',
        )
        ..writeln('}')
        ..writeln();
    }

    if (characteristic.notify.enabled) {
      buffer
        ..writeln(
          'Stream<BluetoothCharacteristicSubscriptionEvent> get ${_lowerFirst(baseName)}SubscriptionEvents {',
        )
        ..writeln(
          'return server.subscriptionEvents.where((event) => _is${baseName}Path(event.path));',
        )
        ..writeln('}')
        ..writeln();
    }

    for (final descriptor in characteristic.descriptors) {
      final descriptorBaseName = _descriptorMemberName(entry, descriptor);
      final descriptorPathName = _descriptorPathName(entry, descriptor);
      buffer
        ..writeln('Future<void> set$descriptorBaseName(Uint8List value) {')
        ..writeln(
          'return server.setDescriptorValue($descriptorPathName, value);',
        )
        ..writeln('}')
        ..writeln();

      if (descriptor.read.enabled) {
        buffer
          ..writeln('Future<Uint8List> read$descriptorBaseName() {')
          ..writeln('return server.readDescriptorValue($descriptorPathName);')
          ..writeln('}')
          ..writeln();
      }
    }

    buffer
      ..writeln(
        'bool _is${baseName}Path(BluetoothGattCharacteristicPath path) {',
      )
      ..writeln("return path.serviceId == '${_escape(entry.service.id)}' &&")
      ..writeln("path.characteristicId == '${_escape(characteristic.id)}';")
      ..writeln('}')
      ..writeln();
  }
}
