import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'audio_waveform.dart';
import 'audio_waveform_validation.dart';
import 'native/dart_edge_audio_native.dart';
import 'native/generated_bindings.dart' as gen;

/// The compact result produced by a [NativeAudioWaveformSession].
final class NativeAudioWaveformResult {
  const NativeAudioWaveformResult({
    required this.waveform,
    required this.sampleRateHz,
    required this.channelCount,
    required this.frameCount,
  });

  final AudioWaveform waveform;
  final int sampleRateHz;
  final int channelCount;

  /// Number of interleaved PCM frames observed by the session.
  final int frameCount;

  Duration get duration => Duration(
    microseconds: (frameCount * Duration.microsecondsPerSecond) ~/ sampleRateHz,
  );

  factory NativeAudioWaveformResult.fromJson(
    Map<String, Object?> json, {
    required Uint8List waveformBytes,
  }) {
    return NativeAudioWaveformResult(
      waveform: AudioWaveform.fromJson(
        json['waveform'] as Map<String, Object?>,
        bytes: waveformBytes,
      ),
      sampleRateHz: json['sampleRateHz'] as int,
      channelCount: json['channelCount'] as int,
      frameCount: json['frameCount'] as int,
    );
  }
}

/// Stateful native waveform accumulator for interleaved PCM16LE chunks.
///
/// [addPcm16] is the compatibility path for Dart-managed bytes and performs a
/// temporary copy into native memory for the synchronous FFI call.
/// [addNativePcm16] borrows an already-native pointer and performs no Dart-side
/// allocation or input copy. The pointer only needs to stay valid until the
/// method returns.
final class NativeAudioWaveformSession {
  NativeAudioWaveformSession({
    required this.sampleRateHz,
    this.channelCount = 1,
    this.waveform = const AudioWaveformSpec(),
  }) {
    RangeError.checkValueInInterval(sampleRateHz, 1, 768000, 'sampleRateHz');
    RangeError.checkValueInInterval(channelCount, 1, 32, 'channelCount');
    validateAudioWaveformSpec(waveform);
    _sessionPtr = DartEdgeAudioNative.createWaveformSession(
      jsonEncode({
        'sampleRateHz': sampleRateHz,
        'channelCount': channelCount,
        'waveform': waveform.toJson(),
      }),
    );
  }

  final int sampleRateHz;
  final int channelCount;
  final AudioWaveformSpec waveform;

  late final Pointer<gen.DartEdgeAudioWaveformSession> _sessionPtr;
  var _closed = false;

  /// Adds complete interleaved PCM16LE frames from Dart-managed memory.
  void addPcm16(Uint8List pcm16LeBytes) {
    _ensureOpen();
    _validateChunkLength(pcm16LeBytes.length);
    DartEdgeAudioNative.addWaveformPcm16(_sessionPtr, pcm16LeBytes);
  }

  /// Adds complete interleaved PCM16LE frames from borrowed native memory.
  ///
  /// Rust reads the pointer synchronously and does not retain it. This is the
  /// preferred path when the transport or recorder already owns native bytes.
  void addNativePcm16({
    required Pointer<Uint8> pcm16LeBytesPtr,
    required int byteLength,
  }) {
    _ensureOpen();
    _validateChunkLength(byteLength);
    if (byteLength > 0 && pcm16LeBytesPtr == nullptr) {
      throw ArgumentError.value(
        pcm16LeBytesPtr,
        'pcm16LeBytesPtr',
        'Pointer must not be null for a non-empty chunk.',
      );
    }
    DartEdgeAudioNative.addWaveformNativePcm16(
      _sessionPtr,
      pcm16LeBytesPtr,
      byteLength,
    );
  }

  /// Finalizes the compact waveform and closes the native session.
  NativeAudioWaveformResult finish() {
    _ensureOpen();
    try {
      final response = DartEdgeAudioNative.finishWaveformSession(_sessionPtr);
      return NativeAudioWaveformResult.fromJson(
        jsonDecode(response.resultJson) as Map<String, Object?>,
        waveformBytes: response.waveformBytes,
      );
    } finally {
      close();
    }
  }

  void close() {
    if (_closed) return;
    DartEdgeAudioNative.freeWaveformSession(_sessionPtr);
    _closed = true;
  }

  void _validateChunkLength(int byteLength) {
    RangeError.checkNotNegative(byteLength, 'byteLength');
    final bytesPerFrame = channelCount * 2;
    if (byteLength % bytesPerFrame != 0) {
      throw ArgumentError.value(
        byteLength,
        'byteLength',
        'PCM16LE chunks must contain complete $channelCount-channel frames.',
      );
    }
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Native audio waveform session is closed.');
    }
  }
}
