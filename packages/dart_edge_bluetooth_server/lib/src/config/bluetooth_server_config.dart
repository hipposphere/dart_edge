import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';

import 'bluetooth_advertisement_config.dart';

final class BluetoothServerConfig {
  const BluetoothServerConfig({
    required this.application,
    this.serverName = 'dart_edge_bluetooth_server',
    this.adapterName,
    this.autoPowerAdapter = true,
    this.advertisement = const BluetoothAdvertisementConfig(),
  });

  final String serverName;
  final String? adapterName;
  final bool autoPowerAdapter;
  final BluetoothAdvertisementConfig advertisement;
  final BluetoothGattApplication application;

  Map<String, Object?> toJson() {
    final advertisedServiceUuids = advertisement.includePrimaryServiceUuids
        ? application.primaryServiceUuids
        : const <String>[];

    return {
      'serverName': serverName,
      'adapterName': ?adapterName,
      'autoPowerAdapter': autoPowerAdapter,
      'advertisement': advertisement.toJson(
        advertisedServiceUuids: advertisedServiceUuids,
      ),
      'application': application.toJson(),
    };
  }
}
