import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart';

import 's3_object_metadata.dart';

/// Metadata and a single-owner native body for one downloaded S3 object.
final class S3GetObjectNativeStreamResult {
  const S3GetObjectNativeStreamResult({
    required this.metadata,
    required this.body,
  });

  final S3ObjectMetadata metadata;
  final NativeByteStreamHandle body;

  /// Cancels and releases the native response body.
  Future<void> close() => body.close();
}
