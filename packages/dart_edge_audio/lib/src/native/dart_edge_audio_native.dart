import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;
import 'package:ffi/ffi.dart';

import '../audio_probe_mode.dart';
import 'generated_bindings.dart' as gen;

final class NativeBytesConversionResponse {
  const NativeBytesConversionResponse({
    required this.resultJson,
    required this.bytes,
  });

  final String resultJson;
  final Uint8List bytes;
}

abstract final class DartEdgeAudioNative {
  static int get abiVersion => gen.dart_edge_audio_native_abi_version();

  static bool get hasBundledAsset => abiVersion >= 1;

  static String probeFile(
    String path, {
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) {
    final requestPtr = jsonEncode({
      'path': path,
      'mode': mode.wireValue,
    }).toNativeUtf8();

    try {
      final resultPtr = gen.dart_edge_audio_probe_file(requestPtr.cast<Char>());
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

  static String probeBytes(
    Uint8List bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) {
    final bytesPtr = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      }

      return probeRawBytes(
        bytesPtr,
        bytes.length,
        fileNameHint: fileNameHint,
        mimeTypeHint: mimeTypeHint,
        mode: mode,
      );
    } finally {
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static String probeRawBytes(
    Pointer<Uint8> bytesPtr,
    int bytesLength, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) {
    final requestPtr = jsonEncode({
      'fileNameHint': fileNameHint,
      'mimeTypeHint': mimeTypeHint,
      'mode': mode.wireValue,
    }).toNativeUtf8();

    try {
      final resultPtr = gen.dart_edge_audio_probe_bytes(
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
        gen.dart_edge_audio_free_string(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
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

  static NativeBytesConversionResponse convertBytes(
    String requestJson,
    Uint8List bytes,
  ) {
    final bytesPtr = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      }

      return convertRawBytes(requestJson, bytesPtr, bytes.length);
    } finally {
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static NativeBytesConversionResponse convertRawBytes(
    String requestJson,
    Pointer<Uint8> bytesPtr,
    int bytesLength,
  ) {
    final requestPtr = requestJson.toNativeUtf8();

    try {
      final resultPtr = gen.dart_edge_audio_convert_bytes(
        requestPtr.cast<Char>(),
        bytesPtr,
        bytesLength,
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

        return NativeBytesConversionResponse(
          resultJson: resultJson,
          bytes: outputBytes,
        );
      } finally {
        gen.dart_edge_audio_free_bytes_result(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
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
