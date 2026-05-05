part of '../bluetooth_code_emitter.dart';

String _emitClientLibrary(
  BluetoothGattApplication application, {
  required String className,
  required String backendClassName,
}) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln()
    ..writeln("import 'dart:async';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln(
      "import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';",
    )
    ..writeln()
    ..writeln('final class $className {')
    ..writeln('const $className({required $backendClassName backend})')
    ..writeln(': _backend = backend;')
    ..writeln()
    ..writeln('final $backendClassName _backend;')
    ..writeln()
    ..writeln('Future<void> connect() => _backend.connect();')
    ..writeln()
    ..writeln('Future<void> disconnect() => _backend.disconnect();')
    ..writeln();

  _emitPathConstants(buffer, application);
  _emitClientMembers(buffer, application);

  buffer.writeln('}');
  return buffer.toString();
}

void _emitClientMembers(StringBuffer buffer, BluetoothGattApplication app) {
  for (final entry in _characteristics(app)) {
    final baseName = entry.memberName;
    final pathName = entry.pathName;
    final characteristic = entry.characteristic;

    if (characteristic.read.enabled) {
      buffer
        ..writeln('Future<Uint8List> read$baseName() {')
        ..writeln('return _backend.readCharacteristic($pathName);')
        ..writeln('}')
        ..writeln();
    }

    if (characteristic.write.enabled) {
      buffer
        ..writeln(
          'Future<void> write$baseName(Uint8List value, {bool withoutResponse = false}) {',
        )
        ..writeln(
          'return _backend.writeCharacteristic($pathName, value, withoutResponse: withoutResponse);',
        )
        ..writeln('}')
        ..writeln();
    }

    if (characteristic.notify.enabled) {
      buffer
        ..writeln('Stream<Uint8List> watch$baseName() {')
        ..writeln('return _backend.subscribeToCharacteristic($pathName);')
        ..writeln('}')
        ..writeln();
    }

    for (final descriptor in characteristic.descriptors) {
      final descriptorBaseName = _descriptorMemberName(entry, descriptor);
      final descriptorPathName = _descriptorPathName(entry, descriptor);
      if (descriptor.read.enabled) {
        buffer
          ..writeln('Future<Uint8List> read$descriptorBaseName() {')
          ..writeln('return _backend.readDescriptor($descriptorPathName);')
          ..writeln('}')
          ..writeln();
      }
      if (descriptor.write.enabled) {
        buffer
          ..writeln('Future<void> write$descriptorBaseName(Uint8List value) {')
          ..writeln(
            'return _backend.writeDescriptor($descriptorPathName, value);',
          )
          ..writeln('}')
          ..writeln();
      }
    }
  }
}
