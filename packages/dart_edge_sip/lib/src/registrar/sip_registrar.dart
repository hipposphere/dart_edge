final class SipRegisteredEndpoint {
  const SipRegisteredEndpoint({
    required this.endpointId,
    required this.contactUri,
    required this.expiresAt,
    this.metadata = const <String, Object?>{},
  });

  final String endpointId;
  final String contactUri;
  final DateTime expiresAt;
  final Map<String, Object?> metadata;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  factory SipRegisteredEndpoint.fromJson(Map<String, Object?> json) {
    return SipRegisteredEndpoint(
      endpointId: json['endpointId'] as String,
      contactUri: json['contactUri'] as String,
      expiresAt: _readExpiresAt(json),
      metadata: _readMetadata(json),
    );
  }
}

DateTime _readExpiresAt(Map<String, Object?> json) {
  final value = json['expiresAt'];
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }

  final epochSeconds = json['expiresAtEpochSeconds'];
  if (epochSeconds is int) {
    return DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    );
  }
  if (epochSeconds is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      epochSeconds.toInt() * 1000,
      isUtc: true,
    );
  }

  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

Map<String, Object?> _readMetadata(Map<String, Object?> json) {
  final value = json['metadata'];
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }
  return const <String, Object?>{};
}
