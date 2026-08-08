import 'dart:typed_data';

import 's3_object_metadata.dart';

/// Metadata and a demand-driven body stream for one downloaded S3 object.
final class S3GetObjectStreamResult {
  const S3GetObjectStreamResult({
    required this.metadata,
    required this.body,
    required this._onClose,
  });
  final S3ObjectMetadata metadata;
  final Stream<Uint8List> body;

  final Future<void> Function() _onClose;

  /// Releases the native response body, even when [body] was never listened to.
  ///
  /// This operation is idempotent.
  Future<void> close() => _onClose();
}
