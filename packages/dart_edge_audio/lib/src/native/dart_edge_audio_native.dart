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

final class NativeStreamConversionResponse {
  const NativeStreamConversionResponse({
    required this.resultJson,
    required this.descriptor,
    required this.contentLength,
  });

  final String resultJson;
  final core_ffi.NativeByteStreamDescriptorData descriptor;
  final int contentLength;
}

abstract final class DartEdgeAudioNative {
  static int get abiVersion => gen.dart_edge_audio_native_abi_version();

  static bool get hasBundledAsset => abiVersion >= 1;

  static void initializeDartApiDl() {
    final result = gen.dart_edge_audio_initialize_dart_api_dl(
      NativeApi.initializeApiDLData,
    );
    if (result == 0) {
      throw StateError(_takeLastError());
    }
  }

  static Pointer<gen.DartEdgeAudioPool> createPool({
    required int workerCount,
    required int maxQueueSize,
    required int completionPort,
  }) {
    RangeError.checkNotNegative(workerCount, 'workerCount');
    RangeError.checkNotNegative(maxQueueSize, 'maxQueueSize');
    final poolPtr = gen.dart_edge_audio_pool_create(
      workerCount,
      maxQueueSize,
      completionPort,
    );
    if (poolPtr == nullptr) {
      throw StateError(_takeLastError());
    }
    return poolPtr;
  }

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

  static int submitPoolProbeBytes(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    String optionsJson,
    Uint8List bytes,
  ) {
    final optionsPtr = optionsJson.toNativeUtf8();
    final bytesPtr = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      }

      return submitPoolProbeRawBytes(
        poolPtr,
        optionsPtr.cast<Char>(),
        bytesPtr,
        bytes.length,
      );
    } finally {
      calloc.free(optionsPtr);
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static int submitPoolProbeNativeBytes(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    String optionsJson,
    Pointer<Uint8> bytesPtr,
    int bytesLength,
  ) {
    final optionsPtr = optionsJson.toNativeUtf8();
    try {
      return submitPoolProbeRawBytes(
        poolPtr,
        optionsPtr.cast<Char>(),
        bytesPtr,
        bytesLength,
      );
    } finally {
      calloc.free(optionsPtr);
    }
  }

  static int submitPoolProbeRawBytes(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    Pointer<Char> optionsPtr,
    Pointer<Uint8> bytesPtr,
    int bytesLength,
  ) {
    RangeError.checkNotNegative(bytesLength, 'bytesLength');
    final jobId = gen.dart_edge_audio_pool_submit_probe_bytes(
      poolPtr,
      optionsPtr,
      bytesPtr,
      bytesLength,
    );
    if (jobId == 0) {
      throw StateError(_takeLastError());
    }
    return jobId;
  }

  static int submitPoolProbeFile(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    String requestJson,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    try {
      final jobId = gen.dart_edge_audio_pool_submit_probe_file(
        poolPtr,
        requestPtr.cast<Char>(),
      );
      if (jobId == 0) {
        throw StateError(_takeLastError());
      }
      return jobId;
    } finally {
      calloc.free(requestPtr);
    }
  }

  static int submitPoolConvertFile(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    String requestJson,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    try {
      final jobId = gen.dart_edge_audio_pool_submit_convert_file(
        poolPtr,
        requestPtr.cast<Char>(),
      );
      if (jobId == 0) {
        throw StateError(_takeLastError());
      }
      return jobId;
    } finally {
      calloc.free(requestPtr);
    }
  }

  static int submitPoolConvertBytes(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    String requestJson,
    Uint8List bytes,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    final bytesPtr = bytes.isEmpty ? nullptr : calloc<Uint8>(bytes.length);

    try {
      if (bytesPtr != nullptr) {
        bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      }

      return submitPoolConvertRawBytes(
        poolPtr,
        requestPtr.cast<Char>(),
        bytesPtr,
        bytes.length,
      );
    } finally {
      calloc.free(requestPtr);
      if (bytesPtr != nullptr) {
        calloc.free(bytesPtr);
      }
    }
  }

  static int submitPoolConvertNativeBytes(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    String requestJson,
    Pointer<Uint8> bytesPtr,
    int bytesLength,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    try {
      return submitPoolConvertRawBytes(
        poolPtr,
        requestPtr.cast<Char>(),
        bytesPtr,
        bytesLength,
      );
    } finally {
      calloc.free(requestPtr);
    }
  }

  static int submitPoolConvertRawBytes(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    Pointer<Char> requestPtr,
    Pointer<Uint8> bytesPtr,
    int bytesLength,
  ) {
    RangeError.checkNotNegative(bytesLength, 'bytesLength');
    final jobId = gen.dart_edge_audio_pool_submit_convert_bytes(
      poolPtr,
      requestPtr,
      bytesPtr,
      bytesLength,
    );
    if (jobId == 0) {
      throw StateError(_takeLastError());
    }
    return jobId;
  }

  /// Transfers every input stream to the native worker pool.
  ///
  /// The native side adopts and releases all descriptors once this FFI call
  /// returns, including when queue submission fails.
  static int submitPoolConcatenateStreams(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    String requestJson,
    List<
      ({
        core_ffi.NativeByteStreamHandle body,
        String? fileNameHint,
        String? mimeTypeHint,
      })
    >
    inputs,
  ) {
    final requestPtr = requestJson.toNativeUtf8();
    final nativeInputs = calloc<gen.NativeAudioStreamInput>(inputs.length);
    final allocations = core_ffi.NativeAllocations();
    final leases = <core_ffi.NativeByteStreamLease>[];
    var adopted = false;
    try {
      for (var index = 0; index < inputs.length; index += 1) {
        final input = inputs[index];
        final lease = input.body.takeDescriptor();
        leases.add(lease);
        final target = (nativeInputs + index).ref;
        _copyNativeByteStream(target.stream, lease.descriptor.ref);
        target
          ..file_name_hint = allocations.optionalString(input.fileNameHint)
          ..mime_type_hint = allocations.optionalString(input.mimeTypeHint);
      }

      final jobId = gen.dart_edge_audio_pool_submit_concatenate_streams(
        poolPtr,
        requestPtr.cast<Char>(),
        nativeInputs,
        inputs.length,
      );
      adopted = true;
      for (final lease in leases) {
        lease.markTransferred();
      }
      if (jobId == 0) {
        throw StateError(_takeLastError());
      }
      return jobId;
    } finally {
      if (!adopted) {
        for (final lease in leases) {
          lease.close();
        }
      }
      allocations.free();
      calloc.free(nativeInputs);
      calloc.free(requestPtr);
    }
  }

  static String takePoolFileResult(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    int jobId,
  ) {
    final resultPtr = gen.dart_edge_audio_pool_take_file_result(poolPtr, jobId);
    return _readNativeString(resultPtr);
  }

  static String takePoolProbeResult(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    int jobId,
  ) {
    final resultPtr = gen.dart_edge_audio_pool_take_probe_result(
      poolPtr,
      jobId,
    );
    return _readNativeString(resultPtr);
  }

  static NativeBytesConversionResponse takePoolConvertResult(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    int jobId,
  ) {
    final resultPtr = gen.dart_edge_audio_pool_take_convert_result(
      poolPtr,
      jobId,
    );
    if (resultPtr == nullptr) {
      throw StateError(_takeLastError());
    }

    try {
      final response = resultPtr.ref;
      return NativeBytesConversionResponse(
        resultJson: response.result_json == nullptr
            ? '{}'
            : response.result_json.cast<Utf8>().toDartString(),
        bytes: core_ffi.copyNativeOwnedBytes(response.bytes),
      );
    } finally {
      gen.dart_edge_audio_free_bytes_result(resultPtr);
    }
  }

  static NativeStreamConversionResponse takePoolStreamResult(
    Pointer<gen.DartEdgeAudioPool> poolPtr,
    int jobId,
  ) {
    final resultPtr = gen.dart_edge_audio_pool_take_stream_result(
      poolPtr,
      jobId,
    );
    if (resultPtr == nullptr) {
      throw StateError(_takeLastError());
    }

    try {
      final response = resultPtr.ref;
      final result = NativeStreamConversionResponse(
        resultJson: response.result_json == nullptr
            ? '{}'
            : response.result_json.cast<Utf8>().toDartString(),
        descriptor: core_ffi.NativeByteStreamDescriptorData.fromDescriptor(
          response.stream,
        ),
        contentLength: response.content_length,
      );
      gen.dart_edge_audio_free_stream_result(resultPtr);
      return result;
    } catch (_) {
      gen.dart_edge_audio_dispose_stream_result(resultPtr);
      rethrow;
    }
  }

  static String readPoolMetrics(Pointer<gen.DartEdgeAudioPool> poolPtr) {
    final resultPtr = gen.dart_edge_audio_pool_metrics(poolPtr);
    return _readNativeString(resultPtr);
  }

  static void freePool(Pointer<gen.DartEdgeAudioPool> poolPtr) {
    if (poolPtr != nullptr) {
      gen.dart_edge_audio_pool_free(poolPtr);
    }
  }
}

void _copyNativeByteStream(
  core_ffi.NativeByteStream target,
  core_ffi.NativeByteStream source,
) {
  target
    ..abi_version = source.abi_version
    ..struct_size = source.struct_size
    ..context = source.context
    ..next = source.next
    ..cancel = source.cancel
    ..free_read = source.free_read
    ..release = source.release;
}

String _readNativeString(Pointer<Char> resultPtr) {
  if (resultPtr == nullptr) {
    throw StateError(_takeLastError());
  }

  try {
    return resultPtr.cast<Utf8>().toDartString();
  } finally {
    gen.dart_edge_audio_free_string(resultPtr);
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
