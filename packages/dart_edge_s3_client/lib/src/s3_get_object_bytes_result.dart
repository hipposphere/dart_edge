import 'dart:typed_data';

import 's3_object_metadata.dart';

/// Result of downloading one object from S3 into memory.
final class S3GetObjectBytesResult {
  const S3GetObjectBytesResult({required this.bytes, required this.metadata});

  final Uint8List bytes;
  final S3ObjectMetadata metadata;

  factory S3GetObjectBytesResult.fromJson(
    Map<String, Object?> json, {
    required Uint8List bytes,
  }) {
    return S3GetObjectBytesResult(
      bytes: bytes,
      metadata: S3ObjectMetadata.fromJson(
        json['metadata'] as Map<String, Object?>,
      ),
    );
  }
}
