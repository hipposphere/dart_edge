import 'dart:typed_data';

import 's3_put_object_bytes_request.dart';

/// Request payload for uploading a local file to S3.
final class S3PutObjectFileRequest {
  const S3PutObjectFileRequest({
    required this.bucket,
    required this.key,
    required this.inputPath,
    this.contentType,
    this.cacheControl,
    this.contentDisposition,
    this.contentEncoding,
    this.contentLanguage,
    this.metadata = const <String, String>{},
  });

  final String bucket;
  final String key;
  final String inputPath;
  final String? contentType;
  final String? cacheControl;
  final String? contentDisposition;
  final String? contentEncoding;
  final String? contentLanguage;
  final Map<String, String> metadata;

  S3PutObjectBytesRequest toBytesRequest(Uint8List bytes) {
    return S3PutObjectBytesRequest(
      bucket: bucket,
      key: key,
      bytes: bytes,
      contentType: contentType,
      cacheControl: cacheControl,
      contentDisposition: contentDisposition,
      contentEncoding: contentEncoding,
      contentLanguage: contentLanguage,
      metadata: metadata,
    );
  }
}
