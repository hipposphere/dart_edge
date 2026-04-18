enum SipTrunkDirection {
  inbound,
  outbound,
  bidirectional;

  String get wireName => switch (this) {
    inbound => 'inbound',
    outbound => 'outbound',
    bidirectional => 'bidirectional',
  };
}

final class SipTrunkConfig {
  const SipTrunkConfig({
    required this.id,
    required this.direction,
    required this.serverUri,
    this.username,
    this.password,
    this.realm,
    this.allowedNumbers = const <String>[],
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final SipTrunkDirection direction;
  final String serverUri;
  final String? username;
  final String? password;
  final String? realm;
  final List<String> allowedNumbers;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'direction': direction.wireName,
    'serverUri': serverUri,
    if (username case final username?) 'username': username,
    if (password case final password?) 'password': password,
    if (realm case final realm?) 'realm': realm,
    if (allowedNumbers.isNotEmpty) 'allowedNumbers': allowedNumbers,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}
