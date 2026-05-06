// GENERATED CODE - DO NOT MODIFY BY HAND.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';
import '../typed_bluetooth_models.dart';

final class OnooSetupBluetoothClient {
  OnooSetupBluetoothClient({required BluetoothClientBackend backend})
    : _backend = backend,
      raw = OnooSetupBluetoothClientRaw._(backend),
      deviceInfo = OnooSetupBluetoothClientDeviceInfoService._(backend),
      wifi = OnooSetupBluetoothClientWifiService._(backend);

  final BluetoothClientBackend _backend;

  final OnooSetupBluetoothClientRaw raw;

  final OnooSetupBluetoothClientDeviceInfoService deviceInfo;

  final OnooSetupBluetoothClientWifiService wifi;

  Future<void> connect() => _backend.connect();

  Future<void> disconnect() => _backend.disconnect();
}

final class OnooSetupBluetoothClientRaw {
  OnooSetupBluetoothClientRaw._(BluetoothClientBackend backend)
    : _backend = backend;

  final BluetoothClientBackend _backend;

  static const deviceInfoFirmwareVersionPath = BluetoothGattCharacteristicPath(
    serviceId: 'device_info',
    characteristicId: 'firmware_version',
  );

  static const wifiCommandPath = BluetoothGattCharacteristicPath(
    serviceId: 'wifi',
    characteristicId: 'command',
  );

  static const wifiResponsePath = BluetoothGattCharacteristicPath(
    serviceId: 'wifi',
    characteristicId: 'response',
  );

  static const wifiStatePath = BluetoothGattCharacteristicPath(
    serviceId: 'wifi',
    characteristicId: 'state',
  );

  Future<Uint8List> readDeviceInfoFirmwareVersion() {
    return _backend.readCharacteristic(deviceInfoFirmwareVersionPath);
  }

  Stream<Uint8List> watchDeviceInfoFirmwareVersion() {
    return _backend.subscribeToCharacteristic(deviceInfoFirmwareVersionPath);
  }

  Future<void> writeWifiCommand(
    Uint8List value, {
    bool withoutResponse = false,
  }) {
    return _backend.writeCharacteristic(
      wifiCommandPath,
      value,
      withoutResponse: withoutResponse,
    );
  }

  Future<Uint8List> readWifiResponse() {
    return _backend.readCharacteristic(wifiResponsePath);
  }

  Stream<Uint8List> watchWifiResponse() {
    return _backend.subscribeToCharacteristic(wifiResponsePath);
  }

  Future<Uint8List> readWifiState() {
    return _backend.readCharacteristic(wifiStatePath);
  }

  Stream<Uint8List> watchWifiState() {
    return _backend.subscribeToCharacteristic(wifiStatePath);
  }
}

final class OnooSetupBluetoothClientDeviceInfoService {
  OnooSetupBluetoothClientDeviceInfoService._(BluetoothClientBackend backend)
    : raw = OnooSetupBluetoothClientDeviceInfoServiceRaw._(backend);

  final OnooSetupBluetoothClientDeviceInfoServiceRaw raw;

  Future<String> readFirmwareVersion() async {
    final value = await raw.readFirmwareVersion();
    return utf8.decode(value);
  }

  Stream<String> watchFirmwareVersion() {
    return raw.watchFirmwareVersion().map((value) => utf8.decode(value));
  }
}

final class OnooSetupBluetoothClientDeviceInfoServiceRaw {
  OnooSetupBluetoothClientDeviceInfoServiceRaw._(BluetoothClientBackend backend)
    : _backend = backend;

  final BluetoothClientBackend _backend;

  static const firmwareVersionPath = BluetoothGattCharacteristicPath(
    serviceId: 'device_info',
    characteristicId: 'firmware_version',
  );

  Future<Uint8List> readFirmwareVersion() {
    return _backend.readCharacteristic(firmwareVersionPath);
  }

  Stream<Uint8List> watchFirmwareVersion() {
    return _backend.subscribeToCharacteristic(firmwareVersionPath);
  }
}

final class OnooSetupBluetoothClientWifiService {
  OnooSetupBluetoothClientWifiService._(BluetoothClientBackend backend)
    : raw = OnooSetupBluetoothClientWifiServiceRaw._(backend);

  final OnooSetupBluetoothClientWifiServiceRaw raw;

  Future<void> writeCommand(
    OnooBluetoothRequest value, {
    bool withoutResponse = false,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value.toJson())));
    return raw.writeCommand(bytes, withoutResponse: withoutResponse);
  }

  Future<OnooBluetoothResponse> readResponse() async {
    final value = await raw.readResponse();
    return OnooBluetoothResponse.fromJson(
      jsonDecode(utf8.decode(value)) as Map<String, Object?>,
    );
  }

  Stream<OnooBluetoothResponse> watchResponse() {
    return raw.watchResponse().map(
      (value) => OnooBluetoothResponse.fromJson(
        jsonDecode(utf8.decode(value)) as Map<String, Object?>,
      ),
    );
  }

  Future<OnooWifiState> readState() async {
    final value = await raw.readState();
    return OnooWifiState.fromJson(
      jsonDecode(utf8.decode(value)) as Map<String, Object?>,
    );
  }

  Stream<OnooWifiState> watchState() {
    return raw.watchState().map(
      (value) => OnooWifiState.fromJson(
        jsonDecode(utf8.decode(value)) as Map<String, Object?>,
      ),
    );
  }
}

final class OnooSetupBluetoothClientWifiServiceRaw {
  OnooSetupBluetoothClientWifiServiceRaw._(BluetoothClientBackend backend)
    : _backend = backend;

  final BluetoothClientBackend _backend;

  static const commandPath = BluetoothGattCharacteristicPath(
    serviceId: 'wifi',
    characteristicId: 'command',
  );

  static const responsePath = BluetoothGattCharacteristicPath(
    serviceId: 'wifi',
    characteristicId: 'response',
  );

  static const statePath = BluetoothGattCharacteristicPath(
    serviceId: 'wifi',
    characteristicId: 'state',
  );

  Future<void> writeCommand(Uint8List value, {bool withoutResponse = false}) {
    return _backend.writeCharacteristic(
      commandPath,
      value,
      withoutResponse: withoutResponse,
    );
  }

  Future<Uint8List> readResponse() {
    return _backend.readCharacteristic(responsePath);
  }

  Stream<Uint8List> watchResponse() {
    return _backend.subscribeToCharacteristic(responsePath);
  }

  Future<Uint8List> readState() {
    return _backend.readCharacteristic(statePath);
  }

  Stream<Uint8List> watchState() {
    return _backend.subscribeToCharacteristic(statePath);
  }
}
