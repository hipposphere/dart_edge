import 'dart:typed_data';

import '../gatt/bluetooth_gatt_path.dart';

enum BluetoothLinkType {
  le,
  brEdr;

  static BluetoothLinkType? parse(String? value) => switch (value) {
    'le' => BluetoothLinkType.le,
    'brEdr' => BluetoothLinkType.brEdr,
    _ => null,
  };
}

enum BluetoothWriteOperation {
  command,
  request,
  reliable;

  static BluetoothWriteOperation? parse(String? value) => switch (value) {
    'command' => BluetoothWriteOperation.command,
    'request' => BluetoothWriteOperation.request,
    'reliable' => BluetoothWriteOperation.reliable,
    _ => null,
  };
}

sealed class BluetoothServerEvent {
  const BluetoothServerEvent({required this.timestamp});

  final DateTime timestamp;

  factory BluetoothServerEvent.fromJson(Map<String, Object?> json) {
    return switch (json['kind']) {
      'characteristicRead' => BluetoothCharacteristicReadEvent.fromJson(json),
      'characteristicWrite' => BluetoothCharacteristicWriteEvent.fromJson(json),
      'descriptorRead' => BluetoothDescriptorReadEvent.fromJson(json),
      'descriptorWrite' => BluetoothDescriptorWriteEvent.fromJson(json),
      'characteristicSubscription' =>
        BluetoothCharacteristicSubscriptionEvent.fromJson(json),
      final Object? value => throw StateError(
        'Unsupported Bluetooth server event kind: $value',
      ),
    };
  }
}

final class BluetoothCharacteristicReadEvent extends BluetoothServerEvent {
  BluetoothCharacteristicReadEvent({
    required super.timestamp,
    required this.path,
    required this.value,
    required this.deviceAddress,
    required this.offset,
    required this.mtu,
    required this.linkType,
  });

  final BluetoothGattCharacteristicPath path;
  final Uint8List value;
  final String deviceAddress;
  final int offset;
  final int mtu;
  final BluetoothLinkType? linkType;

  factory BluetoothCharacteristicReadEvent.fromJson(Map<String, Object?> json) {
    return BluetoothCharacteristicReadEvent(
      timestamp: _readTimestamp(json),
      path: BluetoothGattCharacteristicPath.fromJson(
        json['path'] as Map<String, Object?>,
      ),
      value: _readBytes(json['value']),
      deviceAddress: json['deviceAddress'] as String,
      offset: json['offset'] as int? ?? 0,
      mtu: json['mtu'] as int? ?? 0,
      linkType: BluetoothLinkType.parse(json['linkType'] as String?),
    );
  }
}

final class BluetoothCharacteristicWriteEvent extends BluetoothServerEvent {
  BluetoothCharacteristicWriteEvent({
    required super.timestamp,
    required this.path,
    required this.value,
    required this.deviceAddress,
    required this.offset,
    required this.mtu,
    required this.linkType,
    required this.operation,
    required this.prepareAuthorize,
  });

  final BluetoothGattCharacteristicPath path;
  final Uint8List value;
  final String deviceAddress;
  final int offset;
  final int mtu;
  final BluetoothLinkType? linkType;
  final BluetoothWriteOperation? operation;
  final bool prepareAuthorize;

  factory BluetoothCharacteristicWriteEvent.fromJson(
    Map<String, Object?> json,
  ) {
    return BluetoothCharacteristicWriteEvent(
      timestamp: _readTimestamp(json),
      path: BluetoothGattCharacteristicPath.fromJson(
        json['path'] as Map<String, Object?>,
      ),
      value: _readBytes(json['value']),
      deviceAddress: json['deviceAddress'] as String,
      offset: json['offset'] as int? ?? 0,
      mtu: json['mtu'] as int? ?? 0,
      linkType: BluetoothLinkType.parse(json['linkType'] as String?),
      operation: BluetoothWriteOperation.parse(json['operation'] as String?),
      prepareAuthorize: json['prepareAuthorize'] as bool? ?? false,
    );
  }
}

final class BluetoothDescriptorReadEvent extends BluetoothServerEvent {
  BluetoothDescriptorReadEvent({
    required super.timestamp,
    required this.path,
    required this.value,
    required this.deviceAddress,
    required this.offset,
    required this.linkType,
  });

  final BluetoothGattDescriptorPath path;
  final Uint8List value;
  final String deviceAddress;
  final int offset;
  final BluetoothLinkType? linkType;

  factory BluetoothDescriptorReadEvent.fromJson(Map<String, Object?> json) {
    return BluetoothDescriptorReadEvent(
      timestamp: _readTimestamp(json),
      path: BluetoothGattDescriptorPath.fromJson(
        json['path'] as Map<String, Object?>,
      ),
      value: _readBytes(json['value']),
      deviceAddress: json['deviceAddress'] as String,
      offset: json['offset'] as int? ?? 0,
      linkType: BluetoothLinkType.parse(json['linkType'] as String?),
    );
  }
}

final class BluetoothDescriptorWriteEvent extends BluetoothServerEvent {
  BluetoothDescriptorWriteEvent({
    required super.timestamp,
    required this.path,
    required this.value,
    required this.deviceAddress,
    required this.offset,
    required this.linkType,
    required this.prepareAuthorize,
  });

  final BluetoothGattDescriptorPath path;
  final Uint8List value;
  final String deviceAddress;
  final int offset;
  final BluetoothLinkType? linkType;
  final bool prepareAuthorize;

  factory BluetoothDescriptorWriteEvent.fromJson(Map<String, Object?> json) {
    return BluetoothDescriptorWriteEvent(
      timestamp: _readTimestamp(json),
      path: BluetoothGattDescriptorPath.fromJson(
        json['path'] as Map<String, Object?>,
      ),
      value: _readBytes(json['value']),
      deviceAddress: json['deviceAddress'] as String,
      offset: json['offset'] as int? ?? 0,
      linkType: BluetoothLinkType.parse(json['linkType'] as String?),
      prepareAuthorize: json['prepareAuthorize'] as bool? ?? false,
    );
  }
}

final class BluetoothCharacteristicSubscriptionEvent
    extends BluetoothServerEvent {
  BluetoothCharacteristicSubscriptionEvent({
    required super.timestamp,
    required this.path,
    required this.subscribed,
    required this.confirming,
  });

  final BluetoothGattCharacteristicPath path;
  final bool subscribed;
  final bool confirming;

  factory BluetoothCharacteristicSubscriptionEvent.fromJson(
    Map<String, Object?> json,
  ) {
    return BluetoothCharacteristicSubscriptionEvent(
      timestamp: _readTimestamp(json),
      path: BluetoothGattCharacteristicPath.fromJson(
        json['path'] as Map<String, Object?>,
      ),
      subscribed: json['subscribed'] as bool? ?? false,
      confirming: json['confirming'] as bool? ?? false,
    );
  }
}

DateTime _readTimestamp(Map<String, Object?> json) {
  return DateTime.fromMicrosecondsSinceEpoch(
    json['timestampMicros'] as int? ?? 0,
    isUtc: true,
  );
}

Uint8List _readBytes(Object? value) {
  final bytes = value as List<Object?>? ?? const <Object?>[];
  return Uint8List.fromList([for (final byte in bytes) byte as int]);
}
