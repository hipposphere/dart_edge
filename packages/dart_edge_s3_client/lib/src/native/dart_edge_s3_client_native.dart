import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/ffi.dart' as core_ffi;
import 'package:ffi/ffi.dart';

import 'generated_bindings.dart' as gen;

final class _NativeS3BytesResponse {
  const _NativeS3BytesResponse({required this.resultJson, required this.bytes});

  final String resultJson;
  final Uint8List bytes;
}

abstract final class DartEdgeS3ClientNative {
  static int get abiVersion => gen.dart_edge_s3_client_native_abi_version();

  static int create(String configJson) {
    final configPtr = configJson.toNativeUtf8();

    try {
      final handle = gen.dart_edge_s3_client_create(configPtr.cast<Char>());
      if (handle <= 0) {
        throw StateError(_takeLastError());
      }
      return handle;
    } finally {
      calloc.free(configPtr);
    }
  }

  static void dispose(int handle) {
    gen.dart_edge_s3_client_dispose(handle);
  }

  static String putObjectBytes(
    int handle,
    String requestJson,
    Uint8List bytes,
  ) {
    final bytesPtr = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      }

      return putObjectRawBytes(handle, requestJson, bytesPtr, bytes.length);
    } finally {
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static String putObjectNativeBytes(
    int handle,
    String requestJson,
    core_ffi.NativeBytes bytes,
  ) {
    return putObjectRawBytes(handle, requestJson, bytes.ptr, bytes.len);
  }

  static String putObjectRawBytes(
    int handle,
    String requestJson,
    Pointer<Uint8> bytesPtr,
    int bytesLength,
  ) {
    final requestPtr = requestJson.toNativeUtf8();

    try {
      final resultPtr = gen.dart_edge_s3_client_put_object_bytes(
        handle,
        requestPtr.cast<Char>(),
        bytesPtr,
        bytesLength,
      );
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        return resultPtr.cast<Utf8>().toDartString();
      } finally {
        gen.dart_edge_s3_client_free_string(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
    }
  }

  static _NativeS3BytesResponse getObjectBytes(int handle, String requestJson) {
    final requestPtr = requestJson.toNativeUtf8();

    try {
      final resultPtr = gen.dart_edge_s3_client_get_object_bytes(
        handle,
        requestPtr.cast<Char>(),
      );
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        final result = resultPtr.ref;
        final bytes = core_ffi.copyNativeOwnedBytes(result.bytes);
        final resultJson = result.result_json == nullptr
            ? '{}'
            : result.result_json.cast<Utf8>().toDartString();

        return _NativeS3BytesResponse(resultJson: resultJson, bytes: bytes);
      } finally {
        gen.dart_edge_s3_client_free_bytes_result(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
    }
  }

  static String headObject(int handle, String requestJson) {
    return _callString(
      handle,
      requestJson,
      (handle, request) => gen.dart_edge_s3_client_head_object(handle, request),
    );
  }

  static String deleteObject(int handle, String requestJson) {
    return _callString(
      handle,
      requestJson,
      (handle, request) =>
          gen.dart_edge_s3_client_delete_object(handle, request),
    );
  }
}

String _callString(
  int handle,
  String requestJson,
  Pointer<Char> Function(int handle, Pointer<Char> requestPtr) invoke,
) {
  final requestPtr = requestJson.toNativeUtf8();

  try {
    final resultPtr = invoke(handle, requestPtr.cast<Char>());
    if (resultPtr == nullptr) {
      throw StateError(_takeLastError());
    }

    try {
      return resultPtr.cast<Utf8>().toDartString();
    } finally {
      gen.dart_edge_s3_client_free_string(resultPtr);
    }
  } finally {
    calloc.free(requestPtr);
  }
}

String _takeLastError() {
  final errorPtr = gen.dart_edge_s3_client_take_last_error();
  if (errorPtr == nullptr) {
    return 'dart_edge_s3_client native call failed.';
  }

  try {
    final message = errorPtr.cast<Utf8>().toDartString();
    if (message.isEmpty) {
      return 'dart_edge_s3_client native call failed.';
    }
    return message;
  } finally {
    gen.dart_edge_s3_client_free_string(errorPtr);
  }
}

Map<String, Object?> decodeJsonObject(String value) {
  return jsonDecode(value) as Map<String, Object?>;
}
