import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;

import 'audio_bytes_conversion_request.dart';
import 'audio_bytes_conversion_result.dart';
import 'audio_channel_layout.dart';
import 'audio_file_conversion_request.dart';
import 'audio_file_conversion_result.dart';
import 'audio_metadata.dart';
import 'audio_probe_mode.dart';
import 'audio_target_format.dart';
import 'audio_waveform.dart';
import 'audio_waveform_analysis_request.dart';
import 'audio_waveform_analysis_result.dart';
import 'native_audio_pool.dart';
import 'native_audio_stream_conversion_result.dart';
import 'native_audio_stream_input.dart';

/// Stateless facade for native-backed audio probing and conversion.
abstract final class DartEdgeAudio {
  static NativeAudioPool? _sharedPool;
  static Future<NativeAudioPool>? _sharedPoolFuture;

  /// Starts and warms a shared native worker pool used by audio APIs.
  ///
  /// Await this during server startup to move native audio initialization and
  /// worker startup out of the first real request.
  static Future<void> initialize() async {
    await _ensureSharedPool();
  }

  /// Closes the shared native worker pool created by [initialize].
  static Future<void> close() async {
    final pool = _sharedPool;
    final poolFuture = _sharedPoolFuture;
    _sharedPool = null;
    _sharedPoolFuture = null;
    if (pool != null) {
      await pool.close();
      return;
    }
    final pendingPool = await poolFuture;
    await pendingPool?.close();
  }

  static Future<AudioMetadata> probeFile(
    String path, {
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be empty.');
    }
    return (await _ensureSharedPool()).probeFile(path, mode: mode);
  }

  static Future<AudioMetadata> probeBytes(
    Uint8List bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureBytes(bytes);
    return (await _ensureSharedPool()).probeBytes(
      bytes,
      fileNameHint: fileNameHint,
      mimeTypeHint: mimeTypeHint,
      mode: mode,
    );
  }

  /// Probes borrowed native audio bytes without first copying them into
  /// Dart-managed memory.
  ///
  /// The caller must keep [bytes] alive for the full duration of this call.
  /// This is intended for request-scoped native bodies coming from other Dart
  /// Edge runtime packages.
  static Future<AudioMetadata> probeNativeBytes(
    core_ffi.NativeBytes bytes, {
    String? fileNameHint,
    String? mimeTypeHint,
    AudioProbeMode mode = AudioProbeMode.adaptive,
  }) async {
    _ensureNativeBytes(bytes);
    return (await _ensureSharedPool()).probeNativeBytes(
      bytes,
      fileNameHint: fileNameHint,
      mimeTypeHint: mimeTypeHint,
      mode: mode,
    );
  }

  static Future<AudioFileConversionResult> convertFile(
    AudioFileConversionRequest request,
  ) async {
    _ensureFileRequest(request);
    return (await _ensureSharedPool()).convertFile(request);
  }

  static Future<AudioBytesConversionResult> convertBytes(
    AudioBytesConversionRequest request,
  ) async {
    _ensureBytes(request.inputBytes);
    _ensurePositiveSampleRate(request.targetSampleRate);
    return (await _ensureSharedPool()).convertBytes(request);
  }

  /// Generates a compact waveform without returning converted WAV bytes.
  static Future<AudioWaveformAnalysisResult> analyzeWaveform(
    AudioWaveformAnalysisRequest request,
  ) async {
    _ensureBytes(request.inputBytes);
    _ensurePositiveSampleRate(request.targetSampleRate);
    return (await _ensureSharedPool()).analyzeWaveform(request);
  }

  /// Converts borrowed native audio bytes without first copying them into
  /// Dart-managed memory.
  ///
  /// The caller must keep [bytes] alive for the full duration of this call.
  /// This is intended for request-scoped native bodies coming from other Dart
  /// Edge runtime packages.
  static Future<AudioBytesConversionResult> convertNativeBytes({
    required core_ffi.NativeBytes bytes,
    required AudioTargetFormat targetFormat,
    int? targetSampleRate,
    AudioChannelLayout channelLayout = AudioChannelLayout.keepSource,
    String? fileNameHint,
    String? mimeTypeHint,
    AudioWaveformSpec? waveform,
  }) async {
    _ensureNativeBytes(bytes);
    _ensurePositiveSampleRate(targetSampleRate);
    return (await _ensureSharedPool()).convertNativeBytes(
      bytes: bytes,
      targetFormat: targetFormat,
      targetSampleRate: targetSampleRate,
      channelLayout: channelLayout,
      fileNameHint: fileNameHint,
      mimeTypeHint: mimeTypeHint,
      waveform: waveform,
    );
  }

  /// Normalizes and concatenates native input streams without moving payloads
  /// through the Dart heap.
  static Future<NativeAudioStreamConversionResult> concatenateStreams({
    required List<NativeAudioStreamInput> inputs,
    required AudioTargetFormat targetFormat,
    int? targetSampleRate,
    AudioChannelLayout channelLayout = AudioChannelLayout.keepSource,
  }) async {
    if (inputs.isEmpty) {
      throw ArgumentError.value(
        inputs,
        'inputs',
        'At least one native audio stream is required.',
      );
    }
    _ensurePositiveSampleRate(targetSampleRate);
    return (await _ensureSharedPool()).concatenateStreams(
      inputs: inputs,
      targetFormat: targetFormat,
      targetSampleRate: targetSampleRate,
      channelLayout: channelLayout,
    );
  }

  static void _ensureFileRequest(AudioFileConversionRequest request) {
    if (request.inputPath.isEmpty) {
      throw ArgumentError.value(
        request.inputPath,
        'request.inputPath',
        'inputPath must not be empty.',
      );
    }
    if (request.outputPath.isEmpty) {
      throw ArgumentError.value(
        request.outputPath,
        'request.outputPath',
        'outputPath must not be empty.',
      );
    }
    _ensurePositiveSampleRate(request.targetSampleRate);
  }

  static void _ensureBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Audio byte input must not be empty.',
      );
    }
  }

  static void _ensureNativeBytes(core_ffi.NativeBytes bytes) {
    if (bytes.ptr == nullptr || bytes.len <= 0) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Audio byte input must not be empty.',
      );
    }
  }

  static void _ensurePositiveSampleRate(int? sampleRate) {
    if (sampleRate case final sampleRate? when sampleRate < 1) {
      throw ArgumentError.value(
        sampleRate,
        'sampleRate',
        'sampleRate must be at least 1.',
      );
    }
  }

  static Future<NativeAudioPool> _ensureSharedPool() {
    final pool = _sharedPool;
    if (pool != null) {
      return Future.value(pool);
    }
    return _sharedPoolFuture ??=
        Future(() async {
          final pool = NativeAudioPool();
          await pool.initialize();
          return pool;
        }).then(
          (pool) {
            _sharedPool = pool;
            _sharedPoolFuture = null;
            return pool;
          },
          onError: (Object error, StackTrace stackTrace) {
            _sharedPoolFuture = null;
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
  }
}
