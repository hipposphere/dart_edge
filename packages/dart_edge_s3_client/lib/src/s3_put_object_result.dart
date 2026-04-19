/// Result of uploading one object to S3.
final class S3PutObjectResult {
  const S3PutObjectResult({
    required this.bucket,
    required this.key,
    this.eTag,
    this.versionId,
  });

  final String bucket;
  final String key;
  final String? eTag;
  final String? versionId;

  factory S3PutObjectResult.fromJson(Map<String, Object?> json) {
    return S3PutObjectResult(
      bucket: json['bucket'] as String,
      key: json['key'] as String,
      eTag: json['eTag'] as String?,
      versionId: json['versionId'] as String?,
    );
  }
}
