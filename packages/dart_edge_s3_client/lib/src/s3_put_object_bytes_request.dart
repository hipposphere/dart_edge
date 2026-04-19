import 'dart:typed_data';

/// Request payload for uploading in-memory bytes to S3.
final class S3PutObjectBytesRequest {
  const S3PutObjectBytesRequest({
    required this.bucket,
    required this.key,
    required this.bytes,
    this.contentType,
    this.cacheControl,
    this.contentDisposition,
    this.contentEncoding,
    this.contentLanguage,
    this.metadata = const <String, String>{},
  });

  final String bucket;
  final String key;
  final Uint8List bytes;
  final String? contentType;
  final String? cacheControl;
  final String? contentDisposition;
  final String? contentEncoding;
  final String? contentLanguage;
  final Map<String, String> metadata;

  Map<String, Object?> toJson() {
    return {
      'bucket': bucket,
      'key': key,
      'contentType': contentType,
      'cacheControl': cacheControl,
      'contentDisposition': contentDisposition,
      'contentEncoding': contentEncoding,
      'contentLanguage': contentLanguage,
      'metadata': metadata,
    };
  }
}
