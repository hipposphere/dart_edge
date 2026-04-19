/// Metadata returned for an S3 object.
final class S3ObjectMetadata {
  const S3ObjectMetadata({
    required this.bucket,
    required this.key,
    required this.contentLength,
    this.versionId,
    this.eTag,
    this.contentType,
    this.cacheControl,
    this.contentDisposition,
    this.contentEncoding,
    this.contentLanguage,
    this.metadata = const <String, String>{},
  });

  final String bucket;
  final String key;
  final String? versionId;
  final String? eTag;
  final String? contentType;
  final int contentLength;
  final String? cacheControl;
  final String? contentDisposition;
  final String? contentEncoding;
  final String? contentLanguage;
  final Map<String, String> metadata;

  factory S3ObjectMetadata.fromJson(Map<String, Object?> json) {
    final metadata = json['metadata'] as Map<Object?, Object?>? ?? const {};
    return S3ObjectMetadata(
      bucket: json['bucket'] as String,
      key: json['key'] as String,
      versionId: json['versionId'] as String?,
      eTag: json['eTag'] as String?,
      contentType: json['contentType'] as String?,
      contentLength: json['contentLength'] as int? ?? 0,
      cacheControl: json['cacheControl'] as String?,
      contentDisposition: json['contentDisposition'] as String?,
      contentEncoding: json['contentEncoding'] as String?,
      contentLanguage: json['contentLanguage'] as String?,
      metadata: Map.unmodifiable({
        for (final entry in metadata.entries)
          entry.key.toString(): entry.value.toString(),
      }),
    );
  }
}
