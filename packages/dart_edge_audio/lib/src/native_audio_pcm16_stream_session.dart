part of 'native_audio_pool.dart';

/// Identifies which spool ceiling rejected incoming audio.
enum AudioSpoolLimitScope { session, pool }

/// Raised when accepting a PCM chunk would exceed a configured spool limit.
final class AudioSpoolLimitExceededException implements Exception {
  const AudioSpoolLimitExceededException({
    required this.scope,
    required this.bufferedBytes,
    required this.attemptedBytes,
    required this.maxBytes,
  });

  final AudioSpoolLimitScope scope;
  final int bufferedBytes;
  final int attemptedBytes;
  final int maxBytes;

  @override
  String toString() =>
      'AudioSpoolLimitExceededException: $scope spool has $bufferedBytes bytes; '
      'accepting $attemptedBytes more would exceed its $maxBytes byte limit.';
}

/// Incrementally collects interleaved PCM16LE audio in bounded native memory.
///
/// Create sessions through [NativeAudioPool.createPcm16StreamSession]. The pool
/// enforces a shared spool budget and executes final conversion on its bounded
/// native worker queue.
final class NativeAudioPcm16StreamSession {
  NativeAudioPcm16StreamSession._({
    required NativeAudioPool pool,
    required this.inputSampleRateHz,
    required this.inputChannelCount,
    required this.output,
    required this.targetSampleRateHz,
    required this.channelLayout,
    required this.spoolPolicy,
  }) : _pool = pool {
    RangeError.checkValueInInterval(
      inputSampleRateHz,
      1,
      768000,
      'inputSampleRateHz',
    );
    RangeError.checkValueInInterval(
      inputChannelCount,
      1,
      32,
      'inputChannelCount',
    );
    if (targetSampleRateHz case final value?) {
      RangeError.checkValueInInterval(value, 1, 768000, 'targetSampleRateHz');
    }
    _validateSpoolPolicy(spoolPolicy);

    _sessionPtr = DartEdgeAudioNative.createPcm16StreamSession(
      jsonEncode({
        'inputSampleRateHz': inputSampleRateHz,
        'inputChannelCount': inputChannelCount,
        'targetFormat': output.toJson(),
        'targetSampleRate': targetSampleRateHz,
        'channelLayout': channelLayout.wireValue,
        'maxBufferedBytes': spoolPolicy.maxBytes,
      }),
    );
    _finalizerToken = _Pcm16SessionFinalizerToken(
      sessionAddress: _sessionPtr.address,
      spoolCounters: pool._spoolCounters,
    );
    _pcm16SessionFinalizer.attach(this, _finalizerToken, detach: this);
  }

  final NativeAudioPool _pool;
  final int inputSampleRateHz;
  final int inputChannelCount;
  final AudioOutputSpec output;

  @Deprecated('Use output instead.')
  AudioTargetFormat get targetFormat => switch (output) {
    WavPcm16AudioOutputSpec() => AudioTargetFormat.wavPcm16,
    WavPcm24AudioOutputSpec() => AudioTargetFormat.wavPcm24,
    _ => throw StateError(
      'Compressed outputs do not have a legacy AudioTargetFormat.',
    ),
  };
  final int? targetSampleRateHz;
  final AudioChannelLayout channelLayout;
  final AudioSpoolPolicy spoolPolicy;

  late Pointer<gen.DartEdgeAudioPcm16StreamSession> _sessionPtr;
  late final _Pcm16SessionFinalizerToken _finalizerToken;
  var _bufferedBytes = 0;
  var _closed = false;

  int get bytesPerFrame => inputChannelCount * 2;
  int get bufferedBytes => _bufferedBytes;
  int get remainingCapacityBytes => spoolPolicy.maxBytes - _bufferedBytes;
  bool get isClosed => _closed;

  /// Adds complete interleaved PCM16LE frames.
  void addPcm16(Uint8List pcm16LeBytes) {
    _ensureOpen();
    _validateChunkLength(pcm16LeBytes.lengthInBytes);
    _addReserved(
      pcm16LeBytes.lengthInBytes,
      () => DartEdgeAudioNative.addPcm16StreamBytes(_sessionPtr, pcm16LeBytes),
    );
  }

  /// Consumes one single-owner transport payload.
  void addLease(BinaryPayloadLease lease, {int offset = 0, int? length}) {
    try {
      _ensureOpen();
      final leaseLength = lease.length;
      RangeError.checkValueInInterval(offset, 0, leaseLength, 'offset');
      final resolvedLength = length ?? leaseLength - offset;
      RangeError.checkValueInInterval(
        resolvedLength,
        0,
        leaseLength - offset,
        'length',
      );
      _validateChunkLength(resolvedLength);
      if (lease case native_bridge.NativeBinaryPayloadLease(:final bytesPtr)) {
        addNativePcm16(
          pcm16LeBytesPtr: bytesPtr + offset,
          byteLength: resolvedLength,
        );
      } else {
        final audio = Uint8List.sublistView(
          lease.bytesView,
          offset,
          offset + resolvedLength,
        );
        _addReserved(
          resolvedLength,
          () => DartEdgeAudioNative.addPcm16StreamBytes(_sessionPtr, audio),
        );
      }
    } finally {
      lease.close();
    }
  }

  /// Adds complete PCM16LE frames from a synchronously borrowed pointer.
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
    _addReserved(
      byteLength,
      () => DartEdgeAudioNative.addPcm16StreamNativeBytes(
        _sessionPtr,
        pcm16LeBytesPtr,
        byteLength,
      ),
    );
  }

  /// Seals this session on its pool's bounded native worker queue.
  Future<NativeAudioStreamConversionResult> finish() =>
      _pool._finishPcm16StreamSession(this);

  /// Releases buffered PCM without producing output.
  void close() {
    if (_closed) return;
    _closed = true;
    _pcm16SessionFinalizer.detach(this);
    DartEdgeAudioNative.freePcm16StreamSession(_sessionPtr);
    _sessionPtr = nullptr;
    _pool._unregisterSpoolSession(this);
    _pool._spoolCounters.release(_bufferedBytes);
    _bufferedBytes = 0;
    _finalizerToken.bufferedBytes = 0;
  }

  ({int sessionAddress, int bufferedBytes}) _takeForFinish() {
    _ensureOpen();
    final result = (
      sessionAddress: _sessionPtr.address,
      bufferedBytes: _bufferedBytes,
    );
    _closed = true;
    _sessionPtr = nullptr;
    _pcm16SessionFinalizer.detach(this);
    _pool._unregisterSpoolSession(this);
    _bufferedBytes = 0;
    _finalizerToken.bufferedBytes = 0;
    return result;
  }

  void _addReserved(int byteLength, void Function() addNative) {
    final nextBytes = _bufferedBytes + byteLength;
    if (nextBytes > spoolPolicy.maxBytes) {
      throw AudioSpoolLimitExceededException(
        scope: AudioSpoolLimitScope.session,
        bufferedBytes: _bufferedBytes,
        attemptedBytes: byteLength,
        maxBytes: spoolPolicy.maxBytes,
      );
    }
    _pool._spoolCounters.reserve(byteLength);
    try {
      addNative();
    } catch (_) {
      _pool._spoolCounters.release(byteLength);
      rethrow;
    }
    _bufferedBytes = nextBytes;
    _finalizerToken.bufferedBytes = nextBytes;
  }

  void _validateChunkLength(int byteLength) {
    RangeError.checkNotNegative(byteLength, 'byteLength');
    if (byteLength % bytesPerFrame != 0) {
      throw ArgumentError.value(
        byteLength,
        'byteLength',
        'PCM16LE chunks must contain complete '
            '$inputChannelCount-channel frames.',
      );
    }
  }

  static void _validateSpoolPolicy(AudioSpoolPolicy policy) {
    RangeError.checkValueInInterval(
      policy.maxBytes,
      1,
      1 << 40,
      'spoolPolicy.maxBytes',
    );
    if (policy case AdaptiveAudioSpoolPolicy(:final preferredMemoryBytes)) {
      RangeError.checkValueInInterval(
        preferredMemoryBytes,
        1,
        policy.maxBytes,
        'spoolPolicy.preferredMemoryBytes',
      );
    }
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Native PCM16 audio stream session is closed.');
    }
  }
}

final class _AudioSpoolCounters {
  _AudioSpoolCounters(this.maxBytes);

  final int maxBytes;
  var currentBytes = 0;
  var maxObservedBytes = 0;

  void reserve(int bytes) {
    final nextBytes = currentBytes + bytes;
    if (nextBytes > maxBytes) {
      throw AudioSpoolLimitExceededException(
        scope: AudioSpoolLimitScope.pool,
        bufferedBytes: currentBytes,
        attemptedBytes: bytes,
        maxBytes: maxBytes,
      );
    }
    currentBytes = nextBytes;
    if (currentBytes > maxObservedBytes) maxObservedBytes = currentBytes;
  }

  void release(int bytes) {
    currentBytes -= bytes;
    if (currentBytes < 0) currentBytes = 0;
  }
}

final class _AudioTransientCounters {
  var currentBytes = 0;
  var maxObservedBytes = 0;

  void reserve(int bytes) {
    currentBytes += bytes;
    if (currentBytes > maxObservedBytes) maxObservedBytes = currentBytes;
  }

  void release(int bytes) {
    currentBytes -= bytes;
    if (currentBytes < 0) currentBytes = 0;
  }
}

final class _AudioReservationFinalizerToken {
  const _AudioReservationFinalizerToken({
    required this.spoolCounters,
    required this.transientCounters,
    required this.bytes,
  });

  final _AudioSpoolCounters spoolCounters;
  final _AudioTransientCounters transientCounters;
  final int bytes;
}

final _reservationFinalizer = Finalizer<_AudioReservationFinalizerToken>((
  token,
) {
  token.spoolCounters.release(token.bytes);
  token.transientCounters.release(token.bytes);
});

final class _Pcm16SessionFinalizerToken {
  _Pcm16SessionFinalizerToken({
    required this.sessionAddress,
    required this.spoolCounters,
  });

  final int sessionAddress;
  final _AudioSpoolCounters spoolCounters;
  var bufferedBytes = 0;
}

final _pcm16SessionFinalizer = Finalizer<_Pcm16SessionFinalizerToken>((token) {
  DartEdgeAudioNative.freePcm16StreamSession(
    Pointer<gen.DartEdgeAudioPcm16StreamSession>.fromAddress(
      token.sessionAddress,
    ),
  );
  token.spoolCounters.release(token.bufferedBytes);
});
