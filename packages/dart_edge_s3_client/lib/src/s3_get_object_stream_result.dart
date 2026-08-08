import 'dart:typed_data';

import 's3_object_metadata.dart';

/// Metadata and a demand-driven body stream for one downloaded S3 object.
final class S3GetObjectStreamResult {
  const S3GetObjectStreamResult({required this.metadata, required this.body});

  final S3ObjectMetadata metadata;
  final Stream<Uint8List> body;
}
