import 'dart:typed_data';

import 'package:dart_edge_audio/dart_edge_audio.dart';
import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:test/test.dart';

void main() {
  late NativeAudioPool pool;

  setUp(() {
    pool = NativeAudioPool(
      workerCount: 1,
      maxQueueSize: 4,
      maxActiveSpoolBytes: 1024 * 1024,
    );
  });

  tearDown(() => pool.close());

  test('consumes leased PCM and returns a normalized native WAV', () async {
    final pcm = _pcm16Tone(sampleRateHz: 8000, sampleCount: 800);
    final envelope = Uint8List(4 + pcm.length)
      ..setAll(0, const [1, 2, 3, 4])
      ..setAll(4, pcm);
    final lease = _TrackingPayloadLease(envelope);
    final session = pool.createPcm16StreamSession(
      inputSampleRateHz: 8000,
      targetSampleRateHz: 16000,
      channelLayout: AudioChannelLayout.mono,
    );
    addTearDown(session.close);

    session.addLease(lease, offset: 4);
    expect(lease.closeCount, 1);

    final result = await session.finish();
    addTearDown(result.close);
    expect(result.mimeType, 'audio/wav');
    expect(result.metadata.sampleRate, 16000);
    expect(result.metadata.channelCount, 1);
    expect(result.metadata.bitDepth, 16);
    expect(result.contentLength, greaterThan(44));

    final bytes = await _collect(result.body.openRead());
    expect(bytes.length, result.contentLength);
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    expect(() => session.addPcm16(Uint8List(2)), throwsStateError);
    expect(pool.metrics.pendingFinishBytes, 0);
    expect(pool.metrics.maxObservedPendingFinishBytes, pcm.length);
  });

  test('always closes rejected payload leases', () {
    final lease = _TrackingPayloadLease(Uint8List(3));
    final session = pool.createPcm16StreamSession(inputSampleRateHz: 16000);
    addTearDown(session.close);

    expect(() => session.addLease(lease), throwsArgumentError);
    expect(lease.closeCount, 1);
  });

  test('enforces the native PCM buffer ceiling', () {
    final lease = _TrackingPayloadLease(Uint8List(6));
    final session = pool.createPcm16StreamSession(
      inputSampleRateHz: 16000,
      spoolPolicy: const AudioSpoolPolicy.memory(maxBytes: 4),
    );
    addTearDown(session.close);

    expect(
      () => session.addLease(lease),
      throwsA(
        isA<AudioSpoolLimitExceededException>().having(
          (error) => error.scope,
          'scope',
          AudioSpoolLimitScope.session,
        ),
      ),
    );
    expect(lease.closeCount, 1);
  });

  test('enforces and reports the pool-wide spool ceiling', () {
    final first = pool.createPcm16StreamSession(
      inputSampleRateHz: 16000,
      spoolPolicy: const AudioSpoolPolicy.memory(maxBytes: 1024 * 1024),
    );
    final second = pool.createPcm16StreamSession(
      inputSampleRateHz: 16000,
      spoolPolicy: const AudioSpoolPolicy.memory(maxBytes: 1024 * 1024),
    );
    addTearDown(first.close);
    addTearDown(second.close);

    first.addPcm16(Uint8List(800 * 1024));
    expect(first.bufferedBytes, 800 * 1024);
    expect(first.remainingCapacityBytes, 224 * 1024);
    expect(
      () => second.addPcm16(Uint8List(300 * 1024)),
      throwsA(
        isA<AudioSpoolLimitExceededException>().having(
          (error) => error.scope,
          'scope',
          AudioSpoolLimitScope.pool,
        ),
      ),
    );

    final metrics = pool.metrics;
    expect(metrics.maxActiveSpoolBytes, 1024 * 1024);
    expect(metrics.currentSpoolBytes, 800 * 1024);
    expect(metrics.maxObservedSpoolBytes, 800 * 1024);
  });

  test('validates adaptive spool bounds', () {
    expect(
      () => pool.createPcm16StreamSession(
        inputSampleRateHz: 16000,
        spoolPolicy: const AudioSpoolPolicy.adaptive(
          preferredMemoryBytes: 5,
          maxBytes: 4,
        ),
      ),
      throwsRangeError,
    );
  });

  test('finish consumes an empty session when conversion fails', () async {
    final session = pool.createPcm16StreamSession(inputSampleRateHz: 16000);

    await expectLater(session.finish(), throwsStateError);
    expect(() => session.addPcm16(Uint8List(2)), throwsStateError);
  });
}

Uint8List _pcm16Tone({required int sampleRateHz, required int sampleCount}) {
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < sampleCount; index += 1) {
    final sample = index.isEven ? 12000 : -12000;
    data.setInt16(index * 2, sample, Endian.little);
  }
  return bytes;
}

Future<Uint8List> _collect(Stream<Uint8List> chunks) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in chunks) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

final class _TrackingPayloadLease implements BinaryPayloadLease {
  _TrackingPayloadLease(this._bytes);

  Uint8List? _bytes;
  int closeCount = 0;

  @override
  Uint8List get bytesView => _requireBytes();

  @override
  bool get isClosed => _bytes == null;

  @override
  int get length => _requireBytes().lengthInBytes;

  @override
  void close() {
    if (_bytes == null) return;
    _bytes = null;
    closeCount += 1;
  }

  @override
  Uint8List copyBytes() => Uint8List.fromList(_requireBytes());

  @override
  Uint8List takeBytes() {
    final bytes = _requireBytes();
    _bytes = null;
    closeCount += 1;
    return bytes;
  }

  Uint8List _requireBytes() {
    return _bytes ?? (throw StateError('Payload lease is closed.'));
  }
}
