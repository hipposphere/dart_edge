final class SipEndpointConfig {
  const SipEndpointConfig({
    required this.id,
    required this.extension,
    required this.username,
    required this.password,
    required this.realm,
    this.displayName,
    this.allowRegistrations = true,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String extension;
  final String username;
  final String password;
  final String realm;
  final String? displayName;
  final bool allowRegistrations;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'extension': extension,
    'username': username,
    'password': password,
    'realm': realm,
    'displayName': ?displayName,
    'allowRegistrations': allowRegistrations,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}
