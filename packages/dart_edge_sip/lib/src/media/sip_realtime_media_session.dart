import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/ffi.dart' as core_ffi;
import 'package:ffi/ffi.dart';

import '../native/dart_edge_sip_native_media.dart';
import 'sip_audio.dart';

final class SipOwnedAudioFrame {
  SipOwnedAudioFrame._({
    required core_ffi.NativeOwnedBytes bytes,
    required this.format,
    required this.sequence,
  }) : _bytes = bytes {
    _nativeBytesStorage = calloc<core_ffi.NativeBytes>()
      ..ref.ptr = bytes.ptr
      ..ref.len = bytes.len;
  }

  final core_ffi.NativeOwnedBytes _bytes;
  late final Pointer<core_ffi.NativeBytes> _nativeBytesStorage;

  final SipAudioFormat format;
  final int sequence;
  var _disposed = false;

  core_ffi.NativeBytes get nativeBytes {
    _ensureActive();
    return _nativeBytesStorage.ref;
  }

  int get length {
    _ensureActive();
    return _bytes.len;
  }

  bool get isEmpty => length == 0;

  Uint8List copyBytes() {
    _ensureActive();
    if (_bytes.ptr == nullptr || _bytes.len == 0) {
      return Uint8List(0);
    }
    return Uint8List.fromList(_bytes.ptr.asTypedList(_bytes.len));
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    DartEdgeSipNativeMedia.freeOwnedBytes(_bytes);
    calloc.free(_nativeBytesStorage);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('The SIP audio frame has already been disposed.');
    }
  }
}

final class SipRealtimeMediaSession {
  SipRealtimeMediaSession.internal({
    required this.callId,
    required this.mediaAppId,
    required this.format,
    required int handle,
    required Future<void> Function() detach,
  }) : _handle = handle,
       _detach = detach;

  final String callId;
  final String mediaAppId;
  final SipAudioFormat format;
  final int _handle;
  final Future<void> Function() _detach;

  var _closed = false;

  bool get isClosed => _closed;

  Future<SipOwnedAudioFrame?> pollIncomingFrame() async {
    _ensureOpen();
    final frame = DartEdgeSipNativeMedia.pollIncomingFrame(
      handle: _handle,
      sessionId: callId,
    );
    if (frame == null) {
      return null;
    }
    return SipOwnedAudioFrame._(
      bytes: frame.bytes,
      format: frame.format,
      sequence: frame.sequence,
    );
  }

  Stream<SipOwnedAudioFrame> incomingFrames({
    Duration pollInterval = const Duration(milliseconds: 20),
  }) async* {
    while (!_closed) {
      final frame = await pollIncomingFrame();
      if (frame != null) {
        yield frame;
        continue;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> playAudioBytes(Uint8List bytes, {SipAudioFormat? format}) async {
    _ensureOpen();
    DartEdgeSipNativeMedia.playAudioBytes(
      handle: _handle,
      sessionId: callId,
      bytes: bytes,
      format: format ?? this.format,
    );
  }

  Future<void> playOwnedAudioBytes(
    core_ffi.NativeOwnedBytes bytes, {
    SipAudioFormat? format,
  }) async {
    _ensureOpen();
    DartEdgeSipNativeMedia.playOwnedAudioBytes(
      handle: _handle,
      sessionId: callId,
      bytes: bytes,
      format: format ?? this.format,
    );
  }

  Future<void> clearPlaybackQueue() async {
    _ensureOpen();
    DartEdgeSipNativeMedia.clearPlaybackQueue(
      handle: _handle,
      sessionId: callId,
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _detach();
  }

  void closeFromRuntime() {
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError(
        'The SIP realtime media session has already been closed.',
      );
    }
  }
}
