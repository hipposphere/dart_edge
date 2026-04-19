import 's3_object_metadata.dart';

/// Result of downloading one object from S3 to a local file.
final class S3GetObjectFileResult {
  const S3GetObjectFileResult({
    required this.outputPath,
    required this.metadata,
  });

  final String outputPath;
  final S3ObjectMetadata metadata;
}
