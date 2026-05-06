// GENERATED CODE - DO NOT MODIFY BY HAND.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_edge_bluetooth_server/dart_edge_bluetooth_server.dart';
import '../typed_bluetooth_models.dart';

final class OnooSetupBluetoothServer {
  OnooSetupBluetoothServer(this.server)
    : raw = OnooSetupBluetoothServerRaw._(server),
      deviceInfo = OnooSetupBluetoothServerDeviceInfoService._(server),
      wifi = OnooSetupBluetoothServerWifiService._(server);

  final DartEdgeBluetoothServer server;

  final OnooSetupBluetoothServerRaw raw;

  final OnooSetupBluetoothServerDeviceInfoService deviceInfo;

  final OnooSetupBluetoothServerWifiService wifi;
}

final class OnooSetupBluetoothServerRaw {
  const OnooSetupBluetoothServerRaw._(this.server);

  final DartEdgeBluetoothServer server;

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

  Future<void> setDeviceInfoFirmwareVersion(
    Uint8List value, {
    bool notify = false,
  }) {
    return server.setCharacteristicValue(
      deviceInfoFirmwareVersionPath,
      value,
      notify: notify,
    );
  }

  Future<Uint8List> readDeviceInfoFirmwareVersion() {
    return server.readCharacteristicValue(deviceInfoFirmwareVersionPath);
  }

  Stream<BluetoothCharacteristicReadEvent>
  get deviceInfoFirmwareVersionReadEvents {
    return server.characteristicReadEvents.where(
      (event) => _isDeviceInfoFirmwareVersionPath(event.path),
    );
  }

  Stream<BluetoothCharacteristicSubscriptionEvent>
  get deviceInfoFirmwareVersionSubscriptionEvents {
    return server.subscriptionEvents.where(
      (event) => _isDeviceInfoFirmwareVersionPath(event.path),
    );
  }

  bool _isDeviceInfoFirmwareVersionPath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'device_info' &&
      path.characteristicId == 'firmware_version';

  Future<void> setWifiCommand(Uint8List value, {bool notify = false}) {
    return server.setCharacteristicValue(
      wifiCommandPath,
      value,
      notify: notify,
    );
  }

  Stream<BluetoothCharacteristicWriteEvent> get wifiCommandWriteEvents {
    return server.characteristicWriteEvents.where(
      (event) => _isWifiCommandPath(event.path),
    );
  }

  bool _isWifiCommandPath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'wifi' && path.characteristicId == 'command';

  Future<void> setWifiResponse(Uint8List value, {bool notify = false}) {
    return server.setCharacteristicValue(
      wifiResponsePath,
      value,
      notify: notify,
    );
  }

  Future<Uint8List> readWifiResponse() {
    return server.readCharacteristicValue(wifiResponsePath);
  }

  Stream<BluetoothCharacteristicReadEvent> get wifiResponseReadEvents {
    return server.characteristicReadEvents.where(
      (event) => _isWifiResponsePath(event.path),
    );
  }

  Stream<BluetoothCharacteristicSubscriptionEvent>
  get wifiResponseSubscriptionEvents {
    return server.subscriptionEvents.where(
      (event) => _isWifiResponsePath(event.path),
    );
  }

  bool _isWifiResponsePath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'wifi' && path.characteristicId == 'response';

  Future<void> setWifiState(Uint8List value, {bool notify = false}) {
    return server.setCharacteristicValue(wifiStatePath, value, notify: notify);
  }

  Future<Uint8List> readWifiState() {
    return server.readCharacteristicValue(wifiStatePath);
  }

  Stream<BluetoothCharacteristicReadEvent> get wifiStateReadEvents {
    return server.characteristicReadEvents.where(
      (event) => _isWifiStatePath(event.path),
    );
  }

  Stream<BluetoothCharacteristicSubscriptionEvent>
  get wifiStateSubscriptionEvents {
    return server.subscriptionEvents.where(
      (event) => _isWifiStatePath(event.path),
    );
  }

  bool _isWifiStatePath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'wifi' && path.characteristicId == 'state';
}

final class OnooSetupBluetoothServerDeviceInfoService {
  OnooSetupBluetoothServerDeviceInfoService._(DartEdgeBluetoothServer server)
    : raw = OnooSetupBluetoothServerDeviceInfoServiceRaw._(server);

  final OnooSetupBluetoothServerDeviceInfoServiceRaw raw;

  Future<void> setFirmwareVersion(String value, {bool notify = false}) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return raw.setFirmwareVersion(bytes, notify: notify);
  }

  Future<String> readFirmwareVersion() async {
    final value = await raw.readFirmwareVersion();
    return utf8.decode(value);
  }
}

final class OnooSetupBluetoothServerDeviceInfoServiceRaw {
  const OnooSetupBluetoothServerDeviceInfoServiceRaw._(this.server);

  final DartEdgeBluetoothServer server;

  static const firmwareVersionPath = BluetoothGattCharacteristicPath(
    serviceId: 'device_info',
    characteristicId: 'firmware_version',
  );

  Future<void> setFirmwareVersion(Uint8List value, {bool notify = false}) {
    return server.setCharacteristicValue(
      firmwareVersionPath,
      value,
      notify: notify,
    );
  }

  Future<Uint8List> readFirmwareVersion() {
    return server.readCharacteristicValue(firmwareVersionPath);
  }

  Stream<BluetoothCharacteristicReadEvent> get firmwareVersionReadEvents {
    return server.characteristicReadEvents.where(
      (event) => _isFirmwareVersionPath(event.path),
    );
  }

  Stream<BluetoothCharacteristicSubscriptionEvent>
  get firmwareVersionSubscriptionEvents {
    return server.subscriptionEvents.where(
      (event) => _isFirmwareVersionPath(event.path),
    );
  }

  bool _isFirmwareVersionPath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'device_info' &&
      path.characteristicId == 'firmware_version';
}

final class OnooSetupBluetoothServerWifiService {
  OnooSetupBluetoothServerWifiService._(DartEdgeBluetoothServer server)
    : raw = OnooSetupBluetoothServerWifiServiceRaw._(server);

  final OnooSetupBluetoothServerWifiServiceRaw raw;

  Future<void> setCommand(OnooBluetoothRequest value, {bool notify = false}) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value.toJson())));
    return raw.setCommand(bytes, notify: notify);
  }

  Stream<OnooBluetoothRequest> get commandWriteValues {
    return raw.commandWriteEvents.map((event) {
      final value = event.value;
      return OnooBluetoothRequest.fromJson(
        jsonDecode(utf8.decode(value)) as Map<String, Object?>,
      );
    });
  }

  Future<void> setResponse(OnooBluetoothResponse value, {bool notify = false}) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value.toJson())));
    return raw.setResponse(bytes, notify: notify);
  }

  Future<OnooBluetoothResponse> readResponse() async {
    final value = await raw.readResponse();
    return OnooBluetoothResponse.fromJson(
      jsonDecode(utf8.decode(value)) as Map<String, Object?>,
    );
  }

  Future<void> setState(OnooWifiState value, {bool notify = false}) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(value.toJson())));
    return raw.setState(bytes, notify: notify);
  }

  Future<OnooWifiState> readState() async {
    final value = await raw.readState();
    return OnooWifiState.fromJson(
      jsonDecode(utf8.decode(value)) as Map<String, Object?>,
    );
  }
}

final class OnooSetupBluetoothServerWifiServiceRaw {
  const OnooSetupBluetoothServerWifiServiceRaw._(this.server);

  final DartEdgeBluetoothServer server;

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

  Future<void> setCommand(Uint8List value, {bool notify = false}) {
    return server.setCharacteristicValue(commandPath, value, notify: notify);
  }

  Stream<BluetoothCharacteristicWriteEvent> get commandWriteEvents {
    return server.characteristicWriteEvents.where(
      (event) => _isCommandPath(event.path),
    );
  }

  bool _isCommandPath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'wifi' && path.characteristicId == 'command';

  Future<void> setResponse(Uint8List value, {bool notify = false}) {
    return server.setCharacteristicValue(responsePath, value, notify: notify);
  }

  Future<Uint8List> readResponse() {
    return server.readCharacteristicValue(responsePath);
  }

  Stream<BluetoothCharacteristicReadEvent> get responseReadEvents {
    return server.characteristicReadEvents.where(
      (event) => _isResponsePath(event.path),
    );
  }

  Stream<BluetoothCharacteristicSubscriptionEvent>
  get responseSubscriptionEvents {
    return server.subscriptionEvents.where(
      (event) => _isResponsePath(event.path),
    );
  }

  bool _isResponsePath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'wifi' && path.characteristicId == 'response';

  Future<void> setState(Uint8List value, {bool notify = false}) {
    return server.setCharacteristicValue(statePath, value, notify: notify);
  }

  Future<Uint8List> readState() {
    return server.readCharacteristicValue(statePath);
  }

  Stream<BluetoothCharacteristicReadEvent> get stateReadEvents {
    return server.characteristicReadEvents.where(
      (event) => _isStatePath(event.path),
    );
  }

  Stream<BluetoothCharacteristicSubscriptionEvent> get stateSubscriptionEvents {
    return server.subscriptionEvents.where((event) => _isStatePath(event.path));
  }

  bool _isStatePath(BluetoothGattCharacteristicPath path) =>
      path.serviceId == 'wifi' && path.characteristicId == 'state';
}
