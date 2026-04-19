import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/ffi.dart' as core_ffi;
import 'package:ffi/ffi.dart';

import 'generated_bindings.dart' as gen;

final class _NativeBytesConversionResponse {
  const _NativeBytesConversionResponse({
    required this.resultJson,
    required this.bytes,
  });

  final String resultJson;
  final Uint8List bytes;
}

abstract final class DartEdgeAudioNative {
  static int get abiVersion => gen.dart_edge_audio_native_abi_version();

  static bool get hasBundledAsset => abiVersion >= 1;

  static String probeFile(String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = gen.dart_edge_audio_probe_file(pathPtr.cast<Char>());
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        return resultPtr.cast<Utf8>().toDartString();
      } finally {
        gen.dart_edge_audio_free_string(resultPtr);
      }
    } finally {
      calloc.free(pathPtr);
    }
  }

  static String probeBytes(
    Uint8List bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
  }) {
    final requestPtr = jsonEncode({
      'fileNameHint': fileNameHint,
      'mimeTypeHint': mimeTypeHint,
    }).toNativeUtf8();
    final bytesPtr = calloc<Uint8>(bytes.length);

    try {
      bytesPtr.asTypedList(bytes.length).setAll(0, bytes);

      final resultPtr = gen.dart_edge_audio_probe_bytes(
        requestPtr.cast<Char>(),
        bytesPtr,
        bytes.length,
      );
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        return resultPtr.cast<Utf8>().toDartString();
      } finally {
        gen.dart_edge_audio_free_string(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
      calloc.free(bytesPtr);
    }
  }

  static String convertFile(String requestJson) {
    final requestPtr = requestJson.toNativeUtf8();

    try {
      final resultPtr = gen.dart_edge_audio_convert_file(
        requestPtr.cast<Char>(),
      );
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        return resultPtr.cast<Utf8>().toDartString();
      } finally {
        gen.dart_edge_audio_free_string(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
    }
  }

  static _NativeBytesConversionResponse convertBytes(
    String requestJson,
    Uint8List bytes,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    final bytesPtr = calloc<Uint8>(bytes.length);

    try {
      bytesPtr.asTypedList(bytes.length).setAll(0, bytes);

      final resultPtr = gen.dart_edge_audio_convert_bytes(
        requestPtr.cast<Char>(),
        bytesPtr,
        bytes.length,
      );
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        final response = resultPtr.ref;
        final outputBytes = core_ffi.copyNativeOwnedBytes(response.bytes);

        final resultJson = response.result_json == nullptr
            ? '{}'
            : response.result_json.cast<Utf8>().toDartString();

        return _NativeBytesConversionResponse(
          resultJson: resultJson,
          bytes: outputBytes,
        );
      } finally {
        gen.dart_edge_audio_free_bytes_result(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
      calloc.free(bytesPtr);
    }
  }
}

String _takeLastError() {
  final errorPtr = gen.dart_edge_audio_take_last_error();
  if (errorPtr == nullptr) {
    return 'dart_edge_audio native call failed.';
  }

  try {
    final message = errorPtr.cast<Utf8>().toDartString();
    if (message.isEmpty) {
      return 'dart_edge_audio native call failed.';
    }
    return message;
  } finally {
    gen.dart_edge_audio_free_string(errorPtr);
  }
}
