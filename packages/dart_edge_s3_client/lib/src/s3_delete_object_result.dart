/// Result of deleting one object from S3.
final class S3DeleteObjectResult {
  const S3DeleteObjectResult({
    required this.bucket,
    required this.key,
    this.deleteMarker,
    this.versionId,
  });

  final String bucket;
  final String key;
  final bool? deleteMarker;
  final String? versionId;

  factory S3DeleteObjectResult.fromJson(Map<String, Object?> json) {
    return S3DeleteObjectResult(
      bucket: json['bucket'] as String,
      key: json['key'] as String,
      deleteMarker: json['deleteMarker'] as bool?,
      versionId: json['versionId'] as String?,
    );
  }
}
