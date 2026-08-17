import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as native_bridge;
import 'package:ffi/ffi.dart';

import '../open_ai_audio_client_config.dart';
import '../open_ai_audio_form_field.dart';
import '../open_ai_audio_transcription_request.dart';
import '../open_ai_audio_transcription_response.dart';
import 'generated_bindings.dart' as gen;

abstract final class OpenAiAudioClientNative {
  static int get abiVersion =>
      gen.dart_edge_openai_audio_client_native_abi_version();

  static int create(OpenAiAudioClientConfig config) {
    final allocations = native_bridge.NativeAllocations();
    final configPtr = calloc<gen.NativeOpenAiAudioClientConfig>();
    try {
      final nativeConfig = configPtr.ref;
      nativeConfig.base_url = allocations.requiredString(config.baseUrl);
      nativeConfig.api_key = allocations.optionalString(config.apiKey);
      final headers = _writePairs(<OpenAiAudioFormField>[
        for (final entry in config.headers.entries)
          OpenAiAudioFormField(entry.key, entry.value),
      ], allocations);
      nativeConfig.headers = headers.pointer;
      nativeConfig.headers_len = headers.length;
      nativeConfig.connect_timeout_ms = config.connectTimeout.inMilliseconds;
      nativeConfig.request_timeout_ms = config.requestTimeout.inMilliseconds;
      nativeConfig.max_response_bytes = config.maxResponseBytes;
      nativeConfig.allow_http = config.allowHttp;

      final resultPtr = gen.dart_edge_openai_audio_client_create(configPtr);
      if (resultPtr == nullptr) {
        throw StateError('dart_edge_openai_audio_client create returned null.');
      }
      try {
        final result = resultPtr.ref;
        _throwIfError(result.error);
        if (result.handle <= 0) {
          throw StateError(
            'dart_edge_openai_audio_client create returned no handle.',
          );
        }
        return result.handle;
      } finally {
        gen.dart_edge_openai_audio_client_free_create_result(resultPtr);
      }
    } finally {
      calloc.free(configPtr);
      allocations.free();
    }
  }

  static void dispose(int handle) {
    gen.dart_edge_openai_audio_client_dispose(handle);
  }

  static OpenAiAudioTranscriptionResponse transcribeBytes({
    required int handle,
    required OpenAiAudioTranscriptionRequest request,
    required Uint8List bytes,
  }) {
    final bytesPtr = calloc<Uint8>(bytes.length);
    try {
      bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      return _withRequest(request, (requestPtr) {
        final resultPtr = gen.dart_edge_openai_audio_client_transcribe_bytes(
          handle,
          requestPtr,
          bytesPtr,
          bytes.length,
        );
        return _readResult(resultPtr);
      });
    } finally {
      calloc.free(bytesPtr);
    }
  }

  static OpenAiAudioTranscriptionResponse transcribeNativeStream({
    required int handle,
    required OpenAiAudioTranscriptionRequest request,
    required int descriptorAddress,
    required int contentLength,
  }) {
    final descriptor = Pointer<native_bridge.NativeByteStream>.fromAddress(
      descriptorAddress,
    );
    return _withRequest(request, (requestPtr) {
      final resultPtr = gen
          .dart_edge_openai_audio_client_transcribe_native_stream(
            handle,
            requestPtr,
            descriptor,
            contentLength,
          );
      return _readResult(resultPtr);
    });
  }
}

T _withRequest<T>(
  OpenAiAudioTranscriptionRequest request,
  T Function(Pointer<gen.NativeOpenAiAudioTranscriptionRequest>) action,
) {
  final allocations = native_bridge.NativeAllocations();
  final requestPtr = calloc<gen.NativeOpenAiAudioTranscriptionRequest>();
  try {
    final nativeRequest = requestPtr.ref;
    nativeRequest.filename = allocations.requiredString(request.filename);
    nativeRequest.content_type = allocations.requiredString(
      request.contentType,
    );
    final fields = _writePairs(request.resolvedFields(), allocations);
    nativeRequest.fields = fields.pointer;
    nativeRequest.fields_len = fields.length;
    return action(requestPtr);
  } finally {
    calloc.free(requestPtr);
    allocations.free();
  }
}

OpenAiAudioTranscriptionResponse _readResult(
  Pointer<gen.NativeOpenAiAudioTranscriptionResult> resultPtr,
) {
  if (resultPtr == nullptr) {
    throw StateError('dart_edge_openai_audio_client transcribe returned null.');
  }
  try {
    final result = resultPtr.ref;
    _throwIfError(result.error);
    return OpenAiAudioTranscriptionResponse(
      statusCode: result.status_code,
      body: native_bridge.requiredNativeString(result.body, 'body'),
      contentType: native_bridge.optionalNativeString(result.content_type),
      requestId: native_bridge.optionalNativeString(result.request_id),
    );
  } finally {
    gen.dart_edge_openai_audio_client_free_transcription_result(resultPtr);
  }
}

({Pointer<gen.NativeOpenAiAudioStringPair> pointer, int length}) _writePairs(
  List<OpenAiAudioFormField> values,
  native_bridge.NativeAllocations allocations,
) {
  if (values.isEmpty) {
    return (pointer: nullptr, length: 0);
  }
  final pointer = allocations.track(
    calloc<gen.NativeOpenAiAudioStringPair>(values.length),
  );
  for (var index = 0; index < values.length; index++) {
    pointer[index].key = allocations.requiredString(values[index].name);
    pointer[index].value = allocations.requiredString(values[index].value);
  }
  return (pointer: pointer, length: values.length);
}

void _throwIfError(Pointer<Char> error) {
  final message = native_bridge.optionalNativeString(error);
  if (message != null) {
    throw StateError(message);
  }
}
