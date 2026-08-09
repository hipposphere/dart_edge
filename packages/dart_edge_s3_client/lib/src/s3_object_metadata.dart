/// Metadata returned for an S3 object.
final class S3ObjectMetadata {
  const S3ObjectMetadata({
    required this.bucket,
    required this.key,
    required this.contentLength,
    this.objectLength,
    this.contentRange,
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

  /// Total object length. For full responses this equals [contentLength].
  final int? objectLength;

  /// S3 `Content-Range` value when a ranged GET was requested.
  final String? contentRange;
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
      objectLength: json['objectLength'] as int?,
      contentRange: json['contentRange'] as String?,
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
