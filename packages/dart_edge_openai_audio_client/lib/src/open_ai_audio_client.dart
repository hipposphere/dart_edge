import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart';

import 'native/open_ai_audio_client_native.dart';
import 'open_ai_audio_client_config.dart';
import 'open_ai_audio_client_exception.dart';
import 'open_ai_audio_transcription_request.dart';
import 'open_ai_audio_transcription_response.dart';

/// Native-backed client for OpenAI-compatible file transcription endpoints.
final class OpenAiAudioClient {
  OpenAiAudioClient._(this.config, this._nativeHandle);

  static const nativeAbiVersion = 1;

  final OpenAiAudioClientConfig config;
  final int _nativeHandle;
  var _disposed = false;

  /// Creates one reusable native HTTP client.
  static Future<OpenAiAudioClient> open(OpenAiAudioClientConfig config) async {
    _validateConfig(config);
    final handle = await Isolate.run(() {
      final abiVersion = OpenAiAudioClientNative.abiVersion;
      if (abiVersion != nativeAbiVersion) {
        throw StateError(
          'dart_edge_openai_audio_client ABI mismatch: '
          'expected $nativeAbiVersion, received $abiVersion.',
        );
      }
      return OpenAiAudioClientNative.create(config);
    });
    return OpenAiAudioClient._(config, handle);
  }

  /// Transcribes Dart-owned audio bytes.
  Future<OpenAiAudioTranscriptionResponse> transcribeBytes({
    required Uint8List bytes,
    required OpenAiAudioTranscriptionRequest request,
  }) async {
    _ensureActive();
    _validateRequest(request);
    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Audio bytes must not be empty.',
      );
    }

    final transferable = TransferableTypedData.fromList(<Uint8List>[bytes]);
    final response = await Isolate.run(() {
      final isolatedBytes = transferable.materialize().asUint8List();
      return OpenAiAudioClientNative.transcribeBytes(
        handle: _nativeHandle,
        request: request,
        bytes: isolatedBytes,
      );
    });
    return _requireSuccess(response);
  }

  /// Consumes a native audio body and streams it into multipart encoding.
  ///
  /// The audio remains outside the Dart heap. Ownership of [body] transfers to
  /// this call immediately and is released by the native client on success,
  /// failure, or cancellation.
  Future<OpenAiAudioTranscriptionResponse> transcribeNativeStream({
    required NativeByteStreamHandle body,
    required int contentLength,
    required OpenAiAudioTranscriptionRequest request,
  }) async {
    _ensureActive();
    _validateRequest(request);
    if (contentLength <= 0) {
      throw RangeError.value(
        contentLength,
        'contentLength',
        'Native audio content length must be positive.',
      );
    }

    final lease = body.takeDescriptor();
    final descriptorAddress = lease.descriptor.address;
    try {
      final response = await Isolate.run(
        () => OpenAiAudioClientNative.transcribeNativeStream(
          handle: _nativeHandle,
          request: request,
          descriptorAddress: descriptorAddress,
          contentLength: contentLength,
        ),
      );
      return _requireSuccess(response);
    } finally {
      // The FFI function adopts the producer context before validating or
      // sending the request, so the native side owns release in every outcome.
      lease.markTransferred();
    }
  }

  /// Releases the reusable native client handle.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    OpenAiAudioClientNative.dispose(_nativeHandle);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('OpenAiAudioClient has already been disposed.');
    }
  }
}

OpenAiAudioTranscriptionResponse _requireSuccess(
  OpenAiAudioTranscriptionResponse response,
) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return response;
  }
  throw OpenAiAudioClientException(
    message: 'The transcription provider rejected the request.',
    statusCode: response.statusCode,
    body: response.body,
    requestId: response.requestId,
  );
}

void _validateConfig(OpenAiAudioClientConfig config) {
  final baseUri = Uri.tryParse(config.baseUrl);
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
    throw ArgumentError.value(
      config.baseUrl,
      'config.baseUrl',
      'A valid absolute HTTP(S) provider URL is required.',
    );
  }
  if (baseUri.scheme != 'https' && baseUri.scheme != 'http') {
    throw ArgumentError.value(
      config.baseUrl,
      'config.baseUrl',
      'Only HTTP(S) provider URLs are supported.',
    );
  }
  if (baseUri.scheme == 'http' && !config.allowHttp) {
    throw ArgumentError.value(
      config.baseUrl,
      'config.baseUrl',
      'Set allowHttp for an explicitly trusted local provider.',
    );
  }
  if (baseUri.hasQuery || baseUri.hasFragment) {
    throw ArgumentError.value(
      config.baseUrl,
      'config.baseUrl',
      'Provider URLs must not contain a query or fragment.',
    );
  }
  if (config.connectTimeout <= Duration.zero ||
      config.requestTimeout <= Duration.zero) {
    throw ArgumentError('Client timeouts must be positive.');
  }
  if (config.maxResponseBytes <= 0) {
    throw RangeError.value(
      config.maxResponseBytes,
      'config.maxResponseBytes',
      'Maximum response bytes must be positive.',
    );
  }
  for (final entry in config.headers.entries) {
    if (entry.key.trim().isEmpty || entry.value.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError.value(
        entry,
        'config.headers',
        'Invalid HTTP header.',
      );
    }
  }
}

void _validateRequest(OpenAiAudioTranscriptionRequest request) {
  if (request.model.trim().isEmpty) {
    throw ArgumentError.value(
      request.model,
      'request.model',
      'Model must not be empty.',
    );
  }
  if (request.filename.trim().isEmpty) {
    throw ArgumentError.value(
      request.filename,
      'request.filename',
      'Filename must not be empty.',
    );
  }
  if (request.contentType.trim().isEmpty) {
    throw ArgumentError.value(
      request.contentType,
      'request.contentType',
      'Content type must not be empty.',
    );
  }
  if (request.temperature case final value? when value < 0 || value > 1) {
    throw RangeError.range(value, 0, 1, 'request.temperature');
  }
  for (final field in request.additionalFields) {
    final name = field.name.trim();
    if (name.isEmpty || name == 'file' || name == 'model') {
      throw ArgumentError.value(
        field.name,
        'request.additionalFields',
        'Additional fields must be non-empty and must not replace file or model.',
      );
    }
  }
}
