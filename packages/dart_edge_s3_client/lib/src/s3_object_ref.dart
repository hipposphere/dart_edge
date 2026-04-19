/// Identifies one object in an S3 bucket.
final class S3ObjectRef {
  const S3ObjectRef({
    required this.bucket,
    required this.key,
    this.versionId,
  });

  final String bucket;
  final String key;
  final String? versionId;

  Map<String, Object?> toJson() {
    return {
      'bucket': bucket,
      'key': key,
      'versionId': versionId,
    };
  }
}
