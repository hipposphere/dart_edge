import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart' as gen;

abstract final class DartEdgeVadNative {
  static int get abiVersion => gen.dart_edge_vad_native_abi_version();

  static void initializeDartApiDl() {
    final result = gen.dart_edge_vad_initialize_dart_api_dl(
      NativeApi.initializeApiDLData,
    );
    if (result == 0) {
      throw StateError(_takeLastError());
    }
  }

  static Pointer<gen.DartEdgeVadPool> createSileroPool({
    required int workerCount,
    required int maxQueueSize,
    required int completionPort,
  }) {
    RangeError.checkNotNegative(workerCount, 'workerCount');
    RangeError.checkNotNegative(maxQueueSize, 'maxQueueSize');
    final poolPtr = gen.dart_edge_vad_pool_create(
      workerCount,
      maxQueueSize,
      completionPort,
    );
    if (poolPtr == nullptr) {
      throw StateError(_takeLastError());
    }
    return poolPtr;
  }

  static Pointer<gen.DartEdgeVadStream> createSileroStream(String requestJson) {
    final requestPtr = requestJson.toNativeUtf8();
    try {
      final streamPtr = gen.dart_edge_vad_stream_create(
        requestPtr.cast<Char>(),
      );
      if (streamPtr == nullptr) {
        throw StateError(_takeLastError());
      }
      return streamPtr;
    } finally {
      calloc.free(requestPtr);
    }
  }

  static Pointer<gen.DartEdgeVadTrimStream> createSileroTrimStream(
    String requestJson,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    try {
      final streamPtr = gen.dart_edge_vad_trim_stream_create(
        requestPtr.cast<Char>(),
      );
      if (streamPtr == nullptr) {
        throw StateError(_takeLastError());
      }
      return streamPtr;
    } finally {
      calloc.free(requestPtr);
    }
  }

  static String detectSilero(String requestJson, Uint8List pcm16Bytes) {
    final requestPtr = requestJson.toNativeUtf8();
    final bytesPtr = pcm16Bytes.isEmpty
        ? nullptr
        : calloc<Uint8>(pcm16Bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(pcm16Bytes.length).setAll(0, pcm16Bytes);
      }

      return _detectSileroWithRequestPtr(
        requestPtr.cast<Char>(),
        bytesPtr,
        pcm16Bytes.length,
      );
    } finally {
      calloc.free(requestPtr);
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static String detectSileroPointer(
    String requestJson,
    Pointer<Uint8> pcm16BytesPtr,
    int pcm16ByteLength,
  ) {
    RangeError.checkNotNegative(pcm16ByteLength, 'pcm16ByteLength');
    final requestPtr = requestJson.toNativeUtf8();
    try {
      return _detectSileroWithRequestPtr(
        requestPtr.cast<Char>(),
        pcm16BytesPtr,
        pcm16ByteLength,
      );
    } finally {
      calloc.free(requestPtr);
    }
  }

  static int submitSileroPool(
    Pointer<gen.DartEdgeVadPool> poolPtr,
    String requestJson,
    Uint8List pcm16Bytes,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    final bytesPtr = pcm16Bytes.isEmpty
        ? nullptr
        : calloc<Uint8>(pcm16Bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(pcm16Bytes.length).setAll(0, pcm16Bytes);
      }

      return submitSileroPoolPointer(
        poolPtr,
        requestPtr.cast<Char>(),
        bytesPtr,
        pcm16Bytes.length,
      );
    } finally {
      calloc.free(requestPtr);
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static int submitSileroPoolNativePointer(
    Pointer<gen.DartEdgeVadPool> poolPtr,
    String requestJson,
    Pointer<Uint8> pcm16BytesPtr,
    int pcm16ByteLength,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    try {
      return submitSileroPoolPointer(
        poolPtr,
        requestPtr.cast<Char>(),
        pcm16BytesPtr,
        pcm16ByteLength,
      );
    } finally {
      calloc.free(requestPtr);
    }
  }

  static int submitSileroPoolPointer(
    Pointer<gen.DartEdgeVadPool> poolPtr,
    Pointer<Char> requestPtr,
    Pointer<Uint8> pcm16BytesPtr,
    int pcm16ByteLength,
  ) {
    RangeError.checkNotNegative(pcm16ByteLength, 'pcm16ByteLength');
    final jobId = gen.dart_edge_vad_pool_submit_silero(
      poolPtr,
      requestPtr,
      pcm16BytesPtr,
      pcm16ByteLength,
    );
    if (jobId == 0) {
      throw StateError(_takeLastError());
    }
    return jobId;
  }

  static String takeSileroPoolResult(
    Pointer<gen.DartEdgeVadPool> poolPtr,
    int jobId,
  ) {
    final resultPtr = gen.dart_edge_vad_pool_take_result(poolPtr, jobId);
    return _readNativeResultString(resultPtr);
  }

  static String readSileroPoolMetrics(Pointer<gen.DartEdgeVadPool> poolPtr) {
    final resultPtr = gen.dart_edge_vad_pool_metrics(poolPtr);
    return _readNativeResultString(resultPtr);
  }

  static String processSileroStream(
    Pointer<gen.DartEdgeVadStream> streamPtr,
    Uint8List pcm16Bytes, {
    required bool flush,
  }) {
    final bytesPtr = pcm16Bytes.isEmpty
        ? nullptr
        : calloc<Uint8>(pcm16Bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(pcm16Bytes.length).setAll(0, pcm16Bytes);
      }

      return processSileroStreamPointer(
        streamPtr,
        bytesPtr,
        pcm16Bytes.length,
        flush: flush,
      );
    } finally {
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static String processSileroStreamPointer(
    Pointer<gen.DartEdgeVadStream> streamPtr,
    Pointer<Uint8> pcm16BytesPtr,
    int pcm16ByteLength, {
    required bool flush,
  }) {
    RangeError.checkNotNegative(pcm16ByteLength, 'pcm16ByteLength');
    final resultPtr = gen.dart_edge_vad_stream_process(
      streamPtr,
      pcm16BytesPtr,
      pcm16ByteLength,
      flush ? 1 : 0,
    );
    return _readNativeResultString(resultPtr);
  }

  static void freeSileroStream(Pointer<gen.DartEdgeVadStream> streamPtr) {
    if (streamPtr != nullptr) {
      gen.dart_edge_vad_stream_free(streamPtr);
    }
  }

  static Pointer<gen.DartEdgeVadTrimProcessResult> processSileroTrimStream(
    Pointer<gen.DartEdgeVadTrimStream> streamPtr,
    Uint8List pcm16Bytes, {
    required bool flush,
  }) {
    final bytesPtr = pcm16Bytes.isEmpty
        ? nullptr
        : calloc<Uint8>(pcm16Bytes.length);
    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(pcm16Bytes.length).setAll(0, pcm16Bytes);
      }
      return processSileroTrimStreamPointer(
        streamPtr,
        bytesPtr,
        pcm16Bytes.length,
        flush: flush,
      );
    } finally {
      if (bytesPtr != nullptr) calloc.free(bytesPtr);
    }
  }

  static Pointer<gen.DartEdgeVadTrimProcessResult>
  processSileroTrimStreamPointer(
    Pointer<gen.DartEdgeVadTrimStream> streamPtr,
    Pointer<Uint8> pcm16BytesPtr,
    int pcm16ByteLength, {
    required bool flush,
  }) {
    RangeError.checkNotNegative(pcm16ByteLength, 'pcm16ByteLength');
    final result = gen.dart_edge_vad_trim_stream_process(
      streamPtr,
      pcm16BytesPtr,
      pcm16ByteLength,
      flush ? 1 : 0,
    );
    if (result == nullptr) throw StateError(_takeLastError());
    return result;
  }

  static void freeSileroTrimProcessResult(
    Pointer<gen.DartEdgeVadTrimProcessResult> resultPtr,
  ) {
    if (resultPtr != nullptr) {
      gen.dart_edge_vad_trim_process_result_free(resultPtr);
    }
  }

  static void freeSileroTrimStream(
    Pointer<gen.DartEdgeVadTrimStream> streamPtr,
  ) {
    if (streamPtr != nullptr) gen.dart_edge_vad_trim_stream_free(streamPtr);
  }

  static void freeSileroPool(Pointer<gen.DartEdgeVadPool> poolPtr) {
    if (poolPtr != nullptr) {
      gen.dart_edge_vad_pool_free(poolPtr);
    }
  }
}

String _detectSileroWithRequestPtr(
  Pointer<Char> requestPtr,
  Pointer<Uint8> pcm16BytesPtr,
  int pcm16ByteLength,
) {
  final resultPtr = gen.dart_edge_vad_detect_silero(
    requestPtr,
    pcm16BytesPtr,
    pcm16ByteLength,
  );
  return _readNativeResultString(resultPtr);
}

String _readNativeResultString(Pointer<Char> resultPtr) {
  if (resultPtr == nullptr) {
    throw StateError(_takeLastError());
  }

  try {
    return resultPtr.cast<Utf8>().toDartString();
  } finally {
    gen.dart_edge_vad_free_string(resultPtr);
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
