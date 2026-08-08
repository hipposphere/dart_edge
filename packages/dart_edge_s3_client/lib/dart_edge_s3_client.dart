/// Native-backed S3 client for Dart Edge.
///
/// Import this library when you want a bundled Rust S3 client that can talk to
/// AWS S3 or compatible endpoints such as MinIO and Cloudflare R2.
library;

export 'src/dart_edge_s3_client.dart';
export 'src/s3_client_config.dart';
export 'src/s3_delete_object_result.dart';
export 'src/s3_get_object_bytes_result.dart';
export 'src/s3_get_object_file_result.dart';
export 'src/s3_get_object_stream_result.dart';
export 'src/s3_object_metadata.dart';
export 'src/s3_object_ref.dart';
export 'src/s3_put_object_bytes_request.dart';
export 'src/s3_put_object_file_request.dart';
export 'src/s3_put_object_result.dart';
