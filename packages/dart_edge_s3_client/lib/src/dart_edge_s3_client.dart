import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'native/dart_edge_s3_client_native.dart';
import 's3_client_config.dart';
import 's3_delete_object_result.dart';
import 's3_get_object_bytes_result.dart';
import 's3_get_object_file_result.dart';
import 's3_object_metadata.dart';
import 's3_object_ref.dart';
import 's3_put_object_bytes_request.dart';
import 's3_put_object_file_request.dart';
import 's3_put_object_result.dart';

/// Native-backed S3 client facade.
final class DartEdgeS3Client {
  DartEdgeS3Client._(this.config, this._nativeHandle);

  final S3ClientConfig config;
  final int _nativeHandle;
  var _disposed = false;

  /// Opens one reusable S3 client instance.
  static Future<DartEdgeS3Client> open(S3ClientConfig config) async {
    _validateConfig(config);
    final configJson = jsonEncode(config.toJson());
    final handle = await Isolate.run(
      () => DartEdgeS3ClientNative.create(configJson),
    );
    return DartEdgeS3Client._(config, handle);
  }

  /// Uploads in-memory [request.bytes] to the configured S3 endpoint.
  Future<S3PutObjectResult> putObjectBytes(
    S3PutObjectBytesRequest request,
  ) async {
    _ensureActive();
    _validateBucketAndKey(request.bucket, request.key);

    final requestJson = jsonEncode(request.toJson());
    final transferable = TransferableTypedData.fromList([request.bytes]);

    final resultJson = await Isolate.run(() {
      final bytes = transferable.materialize().asUint8List();
      return DartEdgeS3ClientNative.putObjectBytes(
        _nativeHandle,
        requestJson,
        bytes,
      );
    });

    return S3PutObjectResult.fromJson(decodeJsonObject(resultJson));
  }

  /// Uploads a local file to S3 using the same native bytes path.
  Future<S3PutObjectResult> putObjectFile(
    S3PutObjectFileRequest request,
  ) async {
    _ensureActive();
    _validateBucketAndKey(request.bucket, request.key);
    if (request.inputPath.isEmpty) {
      throw ArgumentError.value(
        request.inputPath,
        'request.inputPath',
        'inputPath must not be empty.',
      );
    }

    final bytes = await File(request.inputPath).readAsBytes();
    return putObjectBytes(request.toBytesRequest(bytes));
  }

  /// Downloads one object into memory using the native owned-bytes result path.
  Future<S3GetObjectBytesResult> getObjectBytes(S3ObjectRef object) async {
    _ensureActive();
    _validateObjectRef(object);
    final requestJson = jsonEncode(object.toJson());

    final payload = await Isolate.run(() {
      final result = DartEdgeS3ClientNative.getObjectBytes(
        _nativeHandle,
        requestJson,
      );
      return <String, Object>{
        'resultJson': result.resultJson,
        'bytes': TransferableTypedData.fromList([result.bytes]),
      };
    });

    return S3GetObjectBytesResult.fromJson(
      decodeJsonObject(payload['resultJson'] as String),
      bytes: (payload['bytes'] as TransferableTypedData)
          .materialize()
          .asUint8List(),
    );
  }

  /// Downloads one object to [outputPath].
  Future<S3GetObjectFileResult> getObjectToFile(
    S3ObjectRef object,
    String outputPath,
  ) async {
    _ensureActive();
    if (outputPath.isEmpty) {
      throw ArgumentError.value(
        outputPath,
        'outputPath',
        'outputPath must not be empty.',
      );
    }

    final result = await getObjectBytes(object);
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(result.bytes, flush: true);

    return S3GetObjectFileResult(
      outputPath: outputPath,
      metadata: result.metadata,
    );
  }

  /// Reads object metadata without downloading the body.
  Future<S3ObjectMetadata> headObject(S3ObjectRef object) async {
    _ensureActive();
    _validateObjectRef(object);
    final requestJson = jsonEncode(object.toJson());

    final resultJson = await Isolate.run(
      () => DartEdgeS3ClientNative.headObject(_nativeHandle, requestJson),
    );
    return S3ObjectMetadata.fromJson(decodeJsonObject(resultJson));
  }

  /// Deletes one object from S3.
  Future<S3DeleteObjectResult> deleteObject(S3ObjectRef object) async {
    _ensureActive();
    _validateObjectRef(object);
    final requestJson = jsonEncode(object.toJson());

    final resultJson = await Isolate.run(
      () => DartEdgeS3ClientNative.deleteObject(_nativeHandle, requestJson),
    );
    return S3DeleteObjectResult.fromJson(decodeJsonObject(resultJson));
  }

  /// Releases the native client handle.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    DartEdgeS3ClientNative.dispose(_nativeHandle);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('DartEdgeS3Client has already been disposed.');
    }
  }
}

void _validateConfig(S3ClientConfig config) {
  if (config.region.isEmpty) {
    throw ArgumentError.value(
      config.region,
      'config.region',
      'region must not be empty.',
    );
  }
  final hasAccessKey = config.accessKeyId != null;
  final hasSecret = config.secretAccessKey != null;
  if (hasAccessKey != hasSecret) {
    throw ArgumentError(
      'accessKeyId and secretAccessKey must be provided together.',
    );
  }
  if (config.sessionToken != null && !hasAccessKey) {
    throw ArgumentError(
      'sessionToken requires accessKeyId and secretAccessKey.',
    );
  }
}

void _validateObjectRef(S3ObjectRef object) {
  _validateBucketAndKey(object.bucket, object.key);
}

void _validateBucketAndKey(String bucket, String key) {
  if (bucket.isEmpty) {
    throw ArgumentError.value(bucket, 'bucket', 'bucket must not be empty.');
  }
  if (key.isEmpty) {
    throw ArgumentError.value(key, 'key', 'key must not be empty.');
  }
}
