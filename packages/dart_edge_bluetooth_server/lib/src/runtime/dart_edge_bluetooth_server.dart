import 'dart:async';
import 'dart:typed_data';

import 'package:dart_edge_bluetooth_protocol/dart_edge_bluetooth_protocol.dart';

import '../config/bluetooth_server_config.dart';
import '../events/bluetooth_server_event.dart';
import '../native/dart_edge_bluetooth_server_native.dart';

final class DartEdgeBluetoothServer {
  DartEdgeBluetoothServer({
    required this._config,
    this._eventPollInterval = const Duration(milliseconds: 200),
  });

  final BluetoothServerConfig _config;
  final Duration _eventPollInterval;
  final StreamController<BluetoothServerEvent> _events =
      StreamController<BluetoothServerEvent>.broadcast();

  int? _handle;
  Timer? _pollTimer;
  var _started = false;
  var _disposed = false;

  static int get nativeAbiVersion => DartEdgeBluetoothServerNative.abiVersion;

  static bool get isSupportedPlatform =>
      DartEdgeBluetoothServerNative.isSupportedPlatform;

  BluetoothServerConfig get config => _config;

  bool get isStarted => _started;

  Stream<BluetoothServerEvent> get events => _events.stream;

  Stream<BluetoothCharacteristicReadEvent> get characteristicReadEvents {
    return _events.stream
        .where((event) => event is BluetoothCharacteristicReadEvent)
        .cast<BluetoothCharacteristicReadEvent>();
  }

  Stream<BluetoothCharacteristicWriteEvent> get characteristicWriteEvents {
    return _events.stream
        .where((event) => event is BluetoothCharacteristicWriteEvent)
        .cast<BluetoothCharacteristicWriteEvent>();
  }

  Stream<BluetoothCharacteristicSubscriptionEvent> get subscriptionEvents {
    return _events.stream
        .where((event) => event is BluetoothCharacteristicSubscriptionEvent)
        .cast<BluetoothCharacteristicSubscriptionEvent>();
  }

  Future<void> start() async {
    _ensureNotDisposed();
    if (_started) {
      return;
    }

    final handle = _handle ??= DartEdgeBluetoothServerNative.create(_config);
    DartEdgeBluetoothServerNative.start(handle);
    _started = true;
    _pollTimer = Timer.periodic(_eventPollInterval, (_) {
      unawaited(_drainEvents());
    });
    await _drainEvents();
  }

  Future<void> stop() async {
    if (!_started) {
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = null;

    final handle = _handle;
    if (handle != null) {
      DartEdgeBluetoothServerNative.stop(handle);
    }
    _started = false;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await stop();
    final handle = _handle;
    if (handle != null) {
      DartEdgeBluetoothServerNative.dispose(handle);
      _handle = null;
    }

    await _events.close();
  }

  Future<void> setCharacteristicValue(
    BluetoothGattCharacteristicPath path,
    Uint8List value, {
    bool notify = false,
  }) async {
    await _issueCommand({
      'kind': 'setCharacteristicValue',
      'path': path.toJson(),
      'value': value.toList(growable: false),
      'notify': notify,
    });
  }

  Future<Uint8List> readCharacteristicValue(
    BluetoothGattCharacteristicPath path,
  ) async {
    final payload = await _issueCommand({
      'kind': 'readCharacteristicValue',
      'path': path.toJson(),
    });
    return _readBytes(payload['value']);
  }

  Future<void> setDescriptorValue(
    BluetoothGattDescriptorPath path,
    Uint8List value,
  ) async {
    await _issueCommand({
      'kind': 'setDescriptorValue',
      'path': path.toJson(),
      'value': value.toList(growable: false),
    });
  }

  Future<Uint8List> readDescriptorValue(
    BluetoothGattDescriptorPath path,
  ) async {
    final payload = await _issueCommand({
      'kind': 'readDescriptorValue',
      'path': path.toJson(),
    });
    return _readBytes(payload['value']);
  }

  Future<Map<String, Object?>> _issueCommand(
    Map<String, Object?> command,
  ) async {
    _ensureStarted();
    final payload = DartEdgeBluetoothServerNative.issueCommand(
      _handle!,
      command,
    );
    await _drainEvents();
    return payload;
  }

  Future<void> _drainEvents() async {
    final handle = _handle;
    if (!_started || handle == null || _events.isClosed) {
      return;
    }

    while (true) {
      final payload = DartEdgeBluetoothServerNative.pollEvent(handle);
      if (payload == null) {
        break;
      }
      _events.add(BluetoothServerEvent.fromJson(payload));
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('DartEdgeBluetoothServer has already been disposed.');
    }
  }

  void _ensureStarted() {
    _ensureNotDisposed();
    if (!_started || _handle == null) {
      throw StateError('DartEdgeBluetoothServer is not started.');
    }
  }
}

Uint8List _readBytes(Object? value) {
  final list = value as List<Object?>? ?? const <Object?>[];
  return Uint8List.fromList([for (final byte in list) byte as int]);
}
