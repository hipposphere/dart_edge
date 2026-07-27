@ffi.DefaultAsset('package:dart_edge_sip/dart_edge_sip.dart')
library;

import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;
import 'package:ffi/ffi.dart';

import '../media/sip_audio.dart';
import 'dart_edge_sip_native.dart';

const _maxIncomingAudioFrameBytes = 4096;

typedef SipNativeAudioFrameData = ({
  Uint8List bytes,
  SipAudioFormat format,
  int sequence,
});

final class DartEdgeSipNativeAudioFrame extends ffi.Struct {
  external core_ffi.NativeOwnedBytes bytes;

  @ffi.Int32()
  external int encoding;

  @ffi.Uint32()
  external int sampleRateHz;

  @ffi.Uint32()
  external int channels;

  @ffi.Uint32()
  external int frameDurationMs;

  @ffi.Uint64()
  external int sequence;
}

final class DartEdgeSipNativeMediaQueueStats extends ffi.Struct {
  @ffi.Uint64()
  external int captureQueuedBytes;
  @ffi.Uint64()
  external int captureCapacityBytes;
  @ffi.Uint64()
  external int captureOverrunCount;
  @ffi.Uint64()
  external int captureUnderrunCount;
  @ffi.Uint64()
  external int captureDroppedBytes;
  @ffi.Uint64()
  external int playbackQueuedBytes;
  @ffi.Uint64()
  external int playbackCapacityBytes;
  @ffi.Uint64()
  external int playbackOverrunCount;
  @ffi.Uint64()
  external int playbackUnderrunCount;
  @ffi.Uint64()
  external int playbackDroppedBytes;
}

@ffi.Native<ffi.Void Function(core_ffi.NativeOwnedBytes)>(
  symbol: 'dart_edge_sip_free_owned_bytes',
)
external void _dartEdgeSipFreeOwnedBytes(core_ffi.NativeOwnedBytes value);

@ffi.Native<
  ffi.Bool Function(
    ffi.Int64,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<DartEdgeSipNativeAudioFrame>,
  )
>(symbol: 'dart_edge_sip_poll_media_frame')
external bool _dartEdgeSipPollMediaFrame(
  int handle,
  ffi.Pointer<ffi.Char> sessionId,
  ffi.Pointer<DartEdgeSipNativeAudioFrame> frameOut,
);

@ffi.Native<
  ffi.Bool Function(
    ffi.Int64,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Uint8>,
    ffi.IntPtr,
    ffi.Uint32,
    ffi.Uint32,
    ffi.Uint32,
  )
>(symbol: 'dart_edge_sip_play_media_copy')
external bool _dartEdgeSipPlayMediaCopy(
  int handle,
  ffi.Pointer<ffi.Char> sessionId,
  ffi.Pointer<ffi.Uint8> bytes,
  int length,
  int sampleRateHz,
  int channels,
  int frameDurationMs,
);

@ffi.Native<
  ffi.Bool Function(
    ffi.Int64,
    ffi.Pointer<ffi.Char>,
    core_ffi.NativeOwnedBytes,
    ffi.Uint32,
    ffi.Uint32,
    ffi.Uint32,
  )
>(symbol: 'dart_edge_sip_play_media_owned')
external bool _dartEdgeSipPlayMediaOwned(
  int handle,
  ffi.Pointer<ffi.Char> sessionId,
  core_ffi.NativeOwnedBytes bytes,
  int sampleRateHz,
  int channels,
  int frameDurationMs,
);

@ffi.Native<ffi.Bool Function(ffi.Int64, ffi.Pointer<ffi.Char>)>(
  symbol: 'dart_edge_sip_clear_media_playback',
)
external bool _dartEdgeSipClearMediaPlayback(
  int handle,
  ffi.Pointer<ffi.Char> sessionId,
);

@ffi.Native<
  ffi.Bool Function(
    ffi.Int64,
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<DartEdgeSipNativeMediaQueueStats>,
  )
>(symbol: 'dart_edge_sip_get_media_queue_stats')
external bool _dartEdgeSipGetMediaQueueStats(
  int handle,
  ffi.Pointer<ffi.Char> sessionId,
  ffi.Pointer<DartEdgeSipNativeMediaQueueStats> statsOut,
);

abstract final class DartEdgeSipNativeMedia {
  static SipNativeAudioFrameData? pollIncomingFrame({
    required int handle,
    required String sessionId,
  }) {
    final sessionIdPtr = sessionId.toNativeUtf8();
    final framePtr = calloc<DartEdgeSipNativeAudioFrame>();
    try {
      final ok = _dartEdgeSipPollMediaFrame(
        handle,
        sessionIdPtr.cast<ffi.Char>(),
        framePtr,
      );
      if (!ok) {
        throw StateError(DartEdgeSipNative.takeLastError());
      }

      final frame = framePtr.ref;
      final nativeBytes = frame.bytes;
      if (nativeBytes.ptr == ffi.nullptr || nativeBytes.len == 0) {
        return null;
      }
      if (nativeBytes.len < 0 ||
          nativeBytes.len > _maxIncomingAudioFrameBytes) {
        throw StateError(
          'Invalid SIP audio frame size from native runtime: '
          '${nativeBytes.len} bytes.',
        );
      }

      try {
        return (
          bytes: core_ffi.copyNativeOwnedBytes(nativeBytes),
          format: SipAudioFormat(
            encoding: switch (frame.encoding) {
              0 => SipAudioEncoding.pcm16le,
              final value => throw StateError(
                'Unsupported SIP audio encoding: $value',
              ),
            },
            sampleRateHz: frame.sampleRateHz,
            channels: frame.channels,
            frameDurationMs: frame.frameDurationMs,
          ),
          sequence: frame.sequence,
        );
      } finally {
        freeOwnedBytes(nativeBytes);
      }
    } finally {
      calloc.free(framePtr);
      calloc.free(sessionIdPtr);
    }
  }

  static void playAudioBytes({
    required int handle,
    required String sessionId,
    required Uint8List bytes,
    required SipAudioFormat format,
  }) {
    final sessionIdPtr = sessionId.toNativeUtf8();
    final bytesPtr = calloc<ffi.Uint8>(bytes.length);
    try {
      bytesPtr.asTypedList(bytes.length).setAll(0, bytes);
      final ok = _dartEdgeSipPlayMediaCopy(
        handle,
        sessionIdPtr.cast<ffi.Char>(),
        bytesPtr,
        bytes.length,
        format.sampleRateHz,
        format.channels,
        format.frameDurationMs,
      );
      if (!ok) {
        throw StateError(DartEdgeSipNative.takeLastError());
      }
    } finally {
      calloc.free(bytesPtr);
      calloc.free(sessionIdPtr);
    }
  }

  static void playOwnedAudioBytes({
    required int handle,
    required String sessionId,
    required core_ffi.NativeOwnedBytes bytes,
    required SipAudioFormat format,
  }) {
    final sessionIdPtr = sessionId.toNativeUtf8();
    try {
      final ok = _dartEdgeSipPlayMediaOwned(
        handle,
        sessionIdPtr.cast<ffi.Char>(),
        bytes,
        format.sampleRateHz,
        format.channels,
        format.frameDurationMs,
      );
      if (!ok) {
        throw StateError(DartEdgeSipNative.takeLastError());
      }
    } finally {
      calloc.free(sessionIdPtr);
    }
  }

  static void freeOwnedBytes(core_ffi.NativeOwnedBytes value) {
    _dartEdgeSipFreeOwnedBytes(value);
  }

  static void clearPlaybackQueue({
    required int handle,
    required String sessionId,
  }) {
    final sessionIdPtr = sessionId.toNativeUtf8();
    try {
      final ok = _dartEdgeSipClearMediaPlayback(
        handle,
        sessionIdPtr.cast<ffi.Char>(),
      );
      if (!ok) {
        throw StateError(DartEdgeSipNative.takeLastError());
      }
    } finally {
      calloc.free(sessionIdPtr);
    }
  }

  static DartEdgeSipNativeMediaQueueStatsData mediaQueueStats({
    required int handle,
    required String sessionId,
  }) {
    final sessionIdPtr = sessionId.toNativeUtf8();
    final statsPtr = calloc<DartEdgeSipNativeMediaQueueStats>();
    try {
      final ok = _dartEdgeSipGetMediaQueueStats(
        handle,
        sessionIdPtr.cast<ffi.Char>(),
        statsPtr,
      );
      if (!ok) {
        throw StateError(DartEdgeSipNative.takeLastError());
      }
      final stats = statsPtr.ref;
      return (
        captureQueuedBytes: stats.captureQueuedBytes,
        captureCapacityBytes: stats.captureCapacityBytes,
        captureOverrunCount: stats.captureOverrunCount,
        captureUnderrunCount: stats.captureUnderrunCount,
        captureDroppedBytes: stats.captureDroppedBytes,
        playbackQueuedBytes: stats.playbackQueuedBytes,
        playbackCapacityBytes: stats.playbackCapacityBytes,
        playbackOverrunCount: stats.playbackOverrunCount,
        playbackUnderrunCount: stats.playbackUnderrunCount,
        playbackDroppedBytes: stats.playbackDroppedBytes,
      );
    } finally {
      calloc.free(statsPtr);
      calloc.free(sessionIdPtr);
    }
  }
}

typedef DartEdgeSipNativeMediaQueueStatsData = ({
  int captureQueuedBytes,
  int captureCapacityBytes,
  int captureOverrunCount,
  int captureUnderrunCount,
  int captureDroppedBytes,
  int playbackQueuedBytes,
  int playbackCapacityBytes,
  int playbackOverrunCount,
  int playbackUnderrunCount,
  int playbackDroppedBytes,
});
