import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/ffi.dart' as core_ffi;
import 'package:ffi/ffi.dart';

import '../s3_client_config.dart';
import '../s3_delete_object_result.dart';
import '../s3_object_metadata.dart';
import '../s3_object_ref.dart';
import '../s3_put_object_result.dart';
import 'generated_bindings.dart' as gen;

final class _NativeS3BytesResponse {
  const _NativeS3BytesResponse({required this.metadata, required this.bytes});

  final S3ObjectMetadata metadata;
  final Uint8List bytes;
}

abstract final class DartEdgeS3ClientNative {
  static int get abiVersion => gen.dart_edge_s3_client_native_abi_version();

  static int create(S3ClientConfig config) {
    final allocations = core_ffi.NativeAllocations();
    final configPtr = calloc<gen.NativeS3ClientConfig>();

    try {
      final nativeConfig = configPtr.ref;
      nativeConfig.region = allocations.optionalString(config.region);
      nativeConfig.endpoint = allocations.optionalString(config.endpoint);
      nativeConfig.access_key_id = allocations.optionalString(
        config.accessKeyId,
      );
      nativeConfig.secret_access_key = allocations.optionalString(
        config.secretAccessKey,
      );
      nativeConfig.session_token = allocations.optionalString(
        config.sessionToken,
      );
      nativeConfig.force_path_style = config.forcePathStyle;
      nativeConfig.allow_http = config.allowHttp;

      final resultPtr = gen.dart_edge_s3_client_create(configPtr);
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_s3_client create returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        if (result.handle <= 0) {
          throw StateError('dart_edge_s3_client create returned no handle.');
        }
        return result.handle;
      } finally {
        gen.dart_edge_s3_client_free_create_result(resultPtr);
      }
    } finally {
      calloc.free(configPtr);
      allocations.free();
    }
  }

  static void dispose(int handle) {
    gen.dart_edge_s3_client_dispose(handle);
  }

  static S3PutObjectResult putObjectBytes({
    required int handle,
    required String bucket,
    required String key,
    required Uint8List bytes,
    String? contentType,
    String? cacheControl,
    String? contentDisposition,
    String? contentEncoding,
    String? contentLanguage,
    Map<String, String> metadata = const <String, String>{},
  }) {
    final bytesPtr = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      }

      return putObjectRawBytes(
        handle: handle,
        bucket: bucket,
        key: key,
        bytesPtr: bytesPtr,
        bytesLength: bytes.length,
        contentType: contentType,
        cacheControl: cacheControl,
        contentDisposition: contentDisposition,
        contentEncoding: contentEncoding,
        contentLanguage: contentLanguage,
        metadata: metadata,
      );
    } finally {
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static S3PutObjectResult putObjectRawBytes({
    required int handle,
    required String bucket,
    required String key,
    required Pointer<Uint8> bytesPtr,
    required int bytesLength,
    String? contentType,
    String? cacheControl,
    String? contentDisposition,
    String? contentEncoding,
    String? contentLanguage,
    Map<String, String> metadata = const <String, String>{},
  }) {
    final allocations = core_ffi.NativeAllocations();
    final requestPtr = calloc<gen.NativeS3PutObjectRequest>();

    try {
      final request = requestPtr.ref;
      request.bucket = allocations.requiredString(bucket);
      request.key = allocations.requiredString(key);
      request.content_type = allocations.optionalString(contentType);
      request.cache_control = allocations.optionalString(cacheControl);
      request.content_disposition = allocations.optionalString(
        contentDisposition,
      );
      request.content_encoding = allocations.optionalString(contentEncoding);
      request.content_language = allocations.optionalString(contentLanguage);
      final nativeMetadata = _writeStringPairs(metadata, allocations);
      request.metadata = nativeMetadata.pointer;
      request.metadata_len = nativeMetadata.length;

      final resultPtr = gen.dart_edge_s3_client_put_object_bytes(
        handle,
        requestPtr,
        bytesPtr,
        bytesLength,
      );
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_s3_client putObject returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        return S3PutObjectResult(
          bucket: core_ffi.requiredNativeString(result.bucket, 'bucket'),
          key: core_ffi.requiredNativeString(result.key, 'key'),
          eTag: core_ffi.optionalNativeString(result.e_tag),
          versionId: core_ffi.optionalNativeString(result.version_id),
        );
      } finally {
        gen.dart_edge_s3_client_free_put_object_result(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
      allocations.free();
    }
  }

  static _NativeS3BytesResponse getObjectBytes(int handle, S3ObjectRef object) {
    final allocations = core_ffi.NativeAllocations();
    final requestPtr = calloc<gen.NativeS3ObjectRef>();

    try {
      _writeObjectRef(requestPtr.ref, object, allocations);
      final resultPtr = gen.dart_edge_s3_client_get_object_bytes(
        handle,
        requestPtr,
      );
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_s3_client getObject returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        return _NativeS3BytesResponse(
          metadata: _readObjectMetadata(result.metadata),
          bytes: core_ffi.copyNativeOwnedBytes(result.bytes),
        );
      } finally {
        gen.dart_edge_s3_client_free_bytes_result(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
      allocations.free();
    }
  }

  static S3ObjectMetadata headObject(int handle, S3ObjectRef object) {
    final allocations = core_ffi.NativeAllocations();
    final requestPtr = calloc<gen.NativeS3ObjectRef>();

    try {
      _writeObjectRef(requestPtr.ref, object, allocations);
      final resultPtr = gen.dart_edge_s3_client_head_object(handle, requestPtr);
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_s3_client headObject returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        return _readObjectMetadata(result);
      } finally {
        gen.dart_edge_s3_client_free_object_metadata(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
      allocations.free();
    }
  }

  static S3DeleteObjectResult deleteObject(int handle, S3ObjectRef object) {
    final allocations = core_ffi.NativeAllocations();
    final requestPtr = calloc<gen.NativeS3ObjectRef>();

    try {
      _writeObjectRef(requestPtr.ref, object, allocations);
      final resultPtr = gen.dart_edge_s3_client_delete_object(
        handle,
        requestPtr,
      );
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_s3_client deleteObject returned null.');
      }

      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        return S3DeleteObjectResult(
          bucket: core_ffi.requiredNativeString(result.bucket, 'bucket'),
          key: core_ffi.requiredNativeString(result.key, 'key'),
          deleteMarker: result.has_delete_marker ? result.delete_marker : null,
          versionId: core_ffi.optionalNativeString(result.version_id),
        );
      } finally {
        gen.dart_edge_s3_client_free_delete_object_result(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
      allocations.free();
    }
  }
}

void _writeObjectRef(
  gen.NativeS3ObjectRef request,
  S3ObjectRef object,
  core_ffi.NativeAllocations allocations,
) {
  request.bucket = allocations.requiredString(object.bucket);
  request.key = allocations.requiredString(object.key);
  request.version_id = allocations.optionalString(object.versionId);
}

S3ObjectMetadata _readObjectMetadata(gen.NativeS3ObjectMetadata value) {
  return S3ObjectMetadata(
    bucket: core_ffi.requiredNativeString(value.bucket, 'bucket'),
    key: core_ffi.requiredNativeString(value.key, 'key'),
    versionId: core_ffi.optionalNativeString(value.version_id),
    eTag: core_ffi.optionalNativeString(value.e_tag),
    contentType: core_ffi.optionalNativeString(value.content_type),
    contentLength: value.content_length,
    cacheControl: core_ffi.optionalNativeString(value.cache_control),
    contentDisposition: core_ffi.optionalNativeString(
      value.content_disposition,
    ),
    contentEncoding: core_ffi.optionalNativeString(value.content_encoding),
    contentLanguage: core_ffi.optionalNativeString(value.content_language),
    metadata: _readStringPairs(value.metadata, value.metadata_len),
  );
}

Map<String, String> _readStringPairs(
  Pointer<gen.NativeS3StringPair> pointer,
  int length,
) {
  if (pointer == nullptr || length <= 0) {
    return const <String, String>{};
  }

  return Map.unmodifiable({
    for (var index = 0; index < length; index += 1)
      core_ffi.requiredNativeString(
        (pointer + index).ref.key,
        'metadata key',
      ): core_ffi.requiredNativeString(
        (pointer + index).ref.value,
        'metadata value',
      ),
  });
}

core_ffi.NativeStringPairs<gen.NativeS3StringPair> _writeStringPairs(
  Map<String, String> values,
  core_ffi.NativeAllocations allocations,
) {
  if (values.isEmpty) {
    return core_ffi.NativeStringPairs<gen.NativeS3StringPair>(
      pointer: nullptr.cast<gen.NativeS3StringPair>(),
      length: 0,
    );
  }

  final pointer = calloc<gen.NativeS3StringPair>(values.length);

  var index = 0;
  for (final entry in values.entries) {
    final pair = (pointer + index).ref;
    pair.key = allocations.requiredString(entry.key);
    pair.value = allocations.requiredString(entry.value);
    index += 1;
  }

  return allocations.trackStringPairs(pointer, values.length);
}

void _throwIfError(Pointer<Char> error) {
  final message = core_ffi.optionalNativeString(error);
  if (message != null && message.isNotEmpty) {
    throw StateError(message);
  }
}
