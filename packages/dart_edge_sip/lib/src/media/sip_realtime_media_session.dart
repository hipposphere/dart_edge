import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_edge_core/ffi.dart' as core_ffi;
import 'package:ffi/ffi.dart';

import '../native/dart_edge_sip_native_media.dart';
import 'sip_audio.dart';

final class SipOwnedAudioFrame {
  SipOwnedAudioFrame._({
    required Uint8List bytes,
    required this.format,
    required this.sequence,
  }) : _bytes = bytes;

  final Uint8List _bytes;
  Pointer<core_ffi.NativeBytes>? _nativeBytesStorage;
  Pointer<Uint8>? _nativeBytesCopy;

  final SipAudioFormat format;
  final int sequence;
  var _disposed = false;

  core_ffi.NativeBytes get nativeBytes {
    _ensureActive();
    final existingStorage = _nativeBytesStorage;
    if (existingStorage != null) {
      return existingStorage.ref;
    }

    final storage = calloc<core_ffi.NativeBytes>();
    final bytesCopy = _bytes.isEmpty ? nullptr : calloc<Uint8>(_bytes.length);
    if (_bytes.isNotEmpty) {
      bytesCopy.asTypedList(_bytes.length).setAll(0, _bytes);
    }
    storage
      ..ref.ptr = bytesCopy
      ..ref.len = _bytes.length;
    _nativeBytesStorage = storage;
    _nativeBytesCopy = bytesCopy;
    return storage.ref;
  }

  int get length {
    _ensureActive();
    return _bytes.length;
  }

  bool get isEmpty => length == 0;

  Uint8List get bytes {
    _ensureActive();
    return _bytes;
  }

  Uint8List copyBytes() {
    _ensureActive();
    if (_bytes.isEmpty) {
      return Uint8List(0);
    }
    return Uint8List.fromList(_bytes);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final nativeBytesCopy = _nativeBytesCopy;
    if (nativeBytesCopy != null && nativeBytesCopy != nullptr) {
      calloc.free(nativeBytesCopy);
    }
    final nativeBytesStorage = _nativeBytesStorage;
    if (nativeBytesStorage != null) {
      calloc.free(nativeBytesStorage);
    }
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
  final Completer<void> _closedCompleter = Completer<void>();

  var _closed = false;

  bool get isClosed => _closed;

  Future<void> get closed => _closedCompleter.future;

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
      await Future.any<void>([Future<void>.delayed(pollInterval), closed]);
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
    _markClosed();
    await _detach();
  }

  void closeFromRuntime() {
    _markClosed();
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError(
        'The SIP realtime media session has already been closed.',
      );
    }
  }

  void _markClosed() {
    if (_closed) {
      return;
    }
    _closed = true;
    _closedCompleter.complete();
  }
}
