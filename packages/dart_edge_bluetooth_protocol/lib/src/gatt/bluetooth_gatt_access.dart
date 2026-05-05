final class BluetoothReadAccess {
  const BluetoothReadAccess({
    this.enabled = false,
    this.requiresEncryption = false,
    this.requiresAuthentication = false,
    this.requiresSecureConnection = false,
    this.emitReadEvents = true,
  });

  const BluetoothReadAccess.enabled({
    bool requiresEncryption = false,
    bool requiresAuthentication = false,
    bool requiresSecureConnection = false,
    bool emitReadEvents = true,
  }) : this(
         enabled: true,
         requiresEncryption: requiresEncryption,
         requiresAuthentication: requiresAuthentication,
         requiresSecureConnection: requiresSecureConnection,
         emitReadEvents: emitReadEvents,
       );

  final bool enabled;
  final bool requiresEncryption;
  final bool requiresAuthentication;
  final bool requiresSecureConnection;
  final bool emitReadEvents;

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'requiresEncryption': requiresEncryption,
      'requiresAuthentication': requiresAuthentication,
      'requiresSecureConnection': requiresSecureConnection,
      'emitReadEvents': emitReadEvents,
    };
  }
}

final class BluetoothWriteAccess {
  const BluetoothWriteAccess({
    this.allowWriteRequest = false,
    this.allowWriteCommand = false,
    this.allowReliableWrite = false,
    this.allowAuthenticatedSignedWrite = false,
    this.requiresEncryption = false,
    this.requiresAuthentication = false,
    this.requiresSecureConnection = false,
    this.persistWrittenValue = true,
    this.emitWriteEvents = true,
    this.notifySubscribersOnWrite = false,
  });

  const BluetoothWriteAccess.requestsAndCommands({
    bool allowReliableWrite = false,
    bool allowAuthenticatedSignedWrite = false,
    bool requiresEncryption = false,
    bool requiresAuthentication = false,
    bool requiresSecureConnection = false,
    bool persistWrittenValue = true,
    bool emitWriteEvents = true,
    bool notifySubscribersOnWrite = false,
  }) : this(
         allowWriteRequest: true,
         allowWriteCommand: true,
         allowReliableWrite: allowReliableWrite,
         allowAuthenticatedSignedWrite: allowAuthenticatedSignedWrite,
         requiresEncryption: requiresEncryption,
         requiresAuthentication: requiresAuthentication,
         requiresSecureConnection: requiresSecureConnection,
         persistWrittenValue: persistWrittenValue,
         emitWriteEvents: emitWriteEvents,
         notifySubscribersOnWrite: notifySubscribersOnWrite,
       );

  final bool allowWriteRequest;
  final bool allowWriteCommand;
  final bool allowReliableWrite;
  final bool allowAuthenticatedSignedWrite;
  final bool requiresEncryption;
  final bool requiresAuthentication;
  final bool requiresSecureConnection;
  final bool persistWrittenValue;
  final bool emitWriteEvents;
  final bool notifySubscribersOnWrite;

  bool get enabled {
    return allowWriteRequest ||
        allowWriteCommand ||
        allowReliableWrite ||
        allowAuthenticatedSignedWrite;
  }

  Map<String, Object?> toJson() {
    return {
      'allowWriteRequest': allowWriteRequest,
      'allowWriteCommand': allowWriteCommand,
      'allowReliableWrite': allowReliableWrite,
      'allowAuthenticatedSignedWrite': allowAuthenticatedSignedWrite,
      'requiresEncryption': requiresEncryption,
      'requiresAuthentication': requiresAuthentication,
      'requiresSecureConnection': requiresSecureConnection,
      'persistWrittenValue': persistWrittenValue,
      'emitWriteEvents': emitWriteEvents,
      'notifySubscribersOnWrite': notifySubscribersOnWrite,
    };
  }
}

final class BluetoothNotifyAccess {
  const BluetoothNotifyAccess({
    this.enabled = false,
    this.indicate = false,
    this.emitSubscriptionEvents = true,
  });

  const BluetoothNotifyAccess.notify({bool emitSubscriptionEvents = true})
    : this(enabled: true, emitSubscriptionEvents: emitSubscriptionEvents);

  const BluetoothNotifyAccess.indicate({bool emitSubscriptionEvents = true})
    : this(
        enabled: true,
        indicate: true,
        emitSubscriptionEvents: emitSubscriptionEvents,
      );

  final bool enabled;
  final bool indicate;
  final bool emitSubscriptionEvents;

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'indicate': indicate,
      'emitSubscriptionEvents': emitSubscriptionEvents,
    };
  }
}
