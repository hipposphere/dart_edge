/// Configuration for creating a native-backed S3 client.
final class S3ClientConfig {
  const S3ClientConfig({
    required this.region,
    this.endpoint,
    this.accessKeyId,
    this.secretAccessKey,
    this.sessionToken,
    this.forcePathStyle = false,
    this.allowHttp = false,
  });

  final String region;
  final String? endpoint;
  final String? accessKeyId;
  final String? secretAccessKey;
  final String? sessionToken;
  final bool forcePathStyle;
  final bool allowHttp;

  Map<String, Object?> toJson() {
    return {
      'region': region,
      'endpoint': endpoint,
      'accessKeyId': accessKeyId,
      'secretAccessKey': secretAccessKey,
      'sessionToken': sessionToken,
      'forcePathStyle': forcePathStyle,
      'allowHttp': allowHttp,
    };
  }
}
