import 'dart:io';

import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';
import 'package:test/test.dart';

void main() {
  test('loads the bundled Bluetooth server asset', () {
    expect(DartEdgeBluetoothServer.nativeAbiVersion, 1);
  });

  test('reports Linux-only platform support for the bluer backend', () {
    expect(DartEdgeBluetoothServer.isSupportedPlatform, Platform.isLinux);
  });
}
