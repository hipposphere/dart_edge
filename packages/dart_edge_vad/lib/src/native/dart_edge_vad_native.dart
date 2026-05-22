import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart' as gen;

abstract final class DartEdgeVadNative {
  static int get abiVersion => gen.dart_edge_vad_native_abi_version();

  static String detectSilero(String requestJson, Uint8List pcm16Bytes) {
    final requestPtr = requestJson.toNativeUtf8();
    final bytesPtr = pcm16Bytes.isEmpty
        ? nullptr
        : calloc<Uint8>(pcm16Bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(pcm16Bytes.length).setAll(0, pcm16Bytes);
      }

      final resultPtr = gen.dart_edge_vad_detect_silero(
        requestPtr.cast<Char>(),
        bytesPtr,
        pcm16Bytes.length,
      );
      if (resultPtr == nullptr) {
        throw StateError(_takeLastError());
      }

      try {
        return resultPtr.cast<Utf8>().toDartString();
      } finally {
        gen.dart_edge_vad_free_string(resultPtr);
      }
    } finally {
      calloc.free(requestPtr);
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }
}

String _takeLastError() {
  final errorPtr = gen.dart_edge_vad_take_last_error();
  if (errorPtr == nullptr) {
    return 'dart_edge_vad native call failed.';
  }

  try {
    final message = errorPtr.cast<Utf8>().toDartString();
    if (message.isEmpty) {
      return 'dart_edge_vad native call failed.';
    }
    return message;
  } finally {
    gen.dart_edge_vad_free_string(errorPtr);
  }
}
