final class OnooBluetoothRequest {
  const OnooBluetoothRequest({
    required this.id,
    required this.ssid,
    required this.password,
  });

  final String id;
  final String ssid;
  final String password;

  factory OnooBluetoothRequest.fromJson(Map<String, Object?> json) {
    return OnooBluetoothRequest(
      id: json['id'] as String,
      ssid: json['ssid'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'ssid': ssid, 'password': password};
  }
}

final class OnooBluetoothResponse {
  const OnooBluetoothResponse({
    required this.id,
    required this.success,
    required this.message,
  });

  final String id;
  final bool success;
  final String message;

  factory OnooBluetoothResponse.fromJson(Map<String, Object?> json) {
    return OnooBluetoothResponse(
      id: json['id'] as String,
      success: json['success'] as bool,
      message: json['message'] as String,
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'success': success, 'message': message};
  }
}

final class OnooWifiState {
  const OnooWifiState({
    required this.connected,
    required this.ssid,
    required this.ipAddress,
  });

  final bool connected;
  final String? ssid;
  final String? ipAddress;

  factory OnooWifiState.fromJson(Map<String, Object?> json) {
    return OnooWifiState(
      connected: json['connected'] as bool,
      ssid: json['ssid'] as String?,
      ipAddress: json['ipAddress'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'connected': connected,
      if (ssid case final value?) 'ssid': value,
      if (ipAddress case final value?) 'ipAddress': value,
    };
  }
}
