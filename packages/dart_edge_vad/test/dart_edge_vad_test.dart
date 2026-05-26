import 'dart:typed_data';

import 'package:dart_edge_vad/dart_edge_vad.dart';
import 'package:dart_edge_vad/src/native/dart_edge_vad_native.dart';
import 'package:test/test.dart';

void main() {
  test('loads the native bundled VAD asset', () {
    expect(DartEdgeVadNative.abiVersion, greaterThanOrEqualTo(1));
  });

  test('Native VAD runs ONNX inference for silence', () async {
    final vad = NativeVad(workerCount: 2);
    addTearDown(vad.close);

    final result = await vad.detect(
      pcm16KhzMono: Int16List(16000),
      sampleRateHz: 16000,
    );

    expect(result.sampleRateHz, 16000);
    expect(result.totalSamples, 16000);
    expect(result.hasSpeech, isFalse);
    expect(result.segments, isEmpty);
  });

  test('Native VAD rejects unsupported sample rates', () async {
    final Vad vad = NativeVad();
    addTearDown((vad as NativeVad).close);

    await expectLater(
      vad.detect(pcm16KhzMono: Int16List(10), sampleRateHz: 8000),
      throwsArgumentError,
    );
  });

  test('Native VAD initialize warms native workers', () async {
    final vad = NativeVad(workerCount: 2);
    addTearDown(vad.close);

    await vad.initialize();

    final result = await vad.detect(
      pcm16KhzMono: Int16List(512),
      sampleRateHz: 16000,
    );
    expect(result.totalSamples, 512);
    expect(result.hasSpeech, isFalse);
  });

  test('Native VAD detects from native PCM16 without wrapper copy', () async {
    final buffer = NativePcm16Buffer(16000);
    final vad = NativeVad(workerCount: 2);
    try {
      final result = await vad.detectNativeBuffer(
        pcm16KhzMono: buffer,
        sampleRateHz: 16000,
      );

      expect(result.sampleRateHz, 16000);
      expect(result.totalSamples, 16000);
      expect(result.hasSpeech, isFalse);
      expect(result.segments, isEmpty);
    } finally {
      await vad.close();
      buffer.close();
    }
  });

  test('Native VAD handles concurrent requests', () async {
    final vad = NativeVad(workerCount: 2, maxQueueSize: 8);
    try {
      await vad.initialize();
      final results = await Future.wait([
        vad.detect(pcm16KhzMono: Int16List(16000), sampleRateHz: 16000),
        vad.detect(pcm16KhzMono: Int16List(512), sampleRateHz: 16000),
      ]);

      expect(results[0].sampleRateHz, 16000);
      expect(results[0].totalSamples, 16000);
      expect(results[0].hasSpeech, isFalse);
      expect(results[1].sampleRateHz, 16000);
      expect(results[1].totalSamples, 512);
      expect(results[1].hasSpeech, isFalse);
    } finally {
      await vad.close();
    }
  });

  test('Native VAD exposes native pool metrics', () async {
    final vad = NativeVad(workerCount: 2, maxQueueSize: 8);
    try {
      final initial = vad.metrics;
      expect(initial.workerCount, 2);
      expect(initial.maxQueueSize, 8);
      expect(initial.submittedJobs, 0);
      expect(initial.pendingResultCount, 0);

      await vad.detect(pcm16KhzMono: Int16List(512), sampleRateHz: 16000);

      final metrics = vad.metrics;
      expect(metrics.submittedJobs, greaterThanOrEqualTo(1));
      expect(metrics.acceptedJobs, greaterThanOrEqualTo(1));
      expect(metrics.startedJobs, greaterThanOrEqualTo(1));
      expect(metrics.completedSuccessJobs, greaterThanOrEqualTo(1));
      expect(metrics.completedErrorJobs, 0);
      expect(metrics.pendingResultCount, 0);
      expect(metrics.activeJobs, 0);
      expect(metrics.completionPostFailedJobs, 0);
    } finally {
      await vad.close();
    }
  });

  test('Native VAD streaming session processes incremental chunks', () {
    final stream = NativeVadStreamingSession();
    try {
      final first = stream.addChunk(Int16List(512));
      expect(first.sampleRateHz, 16000);
      expect(first.totalSamples, 512);
      expect(first.processedSamples, 512);
      expect(first.finished, isFalse);
      expect(first.segments, isEmpty);
      expect(first.probabilities, hasLength(1));

      final finish = stream.finish(Int16List(256));
      expect(finish.totalSamples, 768);
      expect(finish.processedSamples, 768);
      expect(finish.finished, isTrue);
      expect(finish.hasSpeech, isFalse);
      expect(finish.segments, isEmpty);
    } finally {
      stream.close();
    }
  });

  test(
    'Native VAD streaming initialize does not consume stream samples',
    () async {
      final stream = NativeVadStreamingSession();
      try {
        await stream.initialize();

        final first = stream.addChunk(Int16List(512));
        expect(first.totalSamples, 512);
        expect(first.processedSamples, 512);
      } finally {
        stream.close();
      }
    },
  );

  test('Native VAD streaming session processes native PCM16 chunks', () {
    final chunk = NativePcm16Buffer(512);
    final tail = NativePcm16Buffer(256);
    final stream = NativeVadStreamingSession();
    try {
      final first = stream.addNativeChunk(chunk);
      expect(first.sampleRateHz, 16000);
      expect(first.totalSamples, 512);
      expect(first.processedSamples, 512);
      expect(first.probabilities, hasLength(1));

      final finish = stream.finishNative(tail);
      expect(finish.totalSamples, 768);
      expect(finish.processedSamples, 768);
      expect(finish.finished, isTrue);
      expect(finish.segments, isEmpty);
    } finally {
      stream.close();
      tail.close();
      chunk.close();
    }
  });

  test('trims PCM16 by sample segments', () {
    final pcm = Int16List.fromList([1, 2, 3, 4, 5, 6]);

    final trimmed = AudioTrimmer.trimPcm16BySegments(pcm, const [
      VadSegment(startSample: 1, endSample: 3, sampleRateHz: 16000),
      VadSegment(startSample: 4, endSample: 6, sampleRateHz: 16000),
    ]);

    expect(trimmed, [2, 3, 5, 6]);
  });

  test('splits PCM16 by sample segments', () {
    final pcm = Int16List.fromList([1, 2, 3, 4, 5, 6]);

    final chunks = AudioTrimmer.splitPcm16BySegments(pcm, const [
      VadSegment(startSample: 1, endSample: 3, sampleRateHz: 16000),
      VadSegment(startSample: 4, endSample: 6, sampleRateHz: 16000),
    ]);

    expect(chunks, hasLength(2));
    expect(chunks[0], [2, 3]);
    expect(chunks[1], [5, 6]);
  });

  test('trims PCM WAV by segments and keeps a valid header', () {
    final wav = _pcmWav(
      Int16List.fromList([10, 20, 30, 40]),
      sampleRateHz: 16000,
    );

    final trimmed = AudioTrimmer.trimBySegments(wav, const [
      VadSegment(startSample: 1, endSample: 3, sampleRateHz: 16000),
    ]);
    final parsed = WavAudio.parse(trimmed);

    expect(parsed.sampleRateHz, 16000);
    expect(parsed.channels, 1);
    expect(parsed.bitsPerSample, 16);
    expect(parsed.sampleCount, 2);
    expect(trimmed.length, 48);
  });

  test('splits PCM WAV by segments and keeps valid headers', () {
    final wav = _pcmWav(
      Int16List.fromList([10, 20, 30, 40, 50, 60]),
      sampleRateHz: 16000,
    );

    final chunks = AudioTrimmer.splitWavBySegments(wav, const [
      VadSegment(startSample: 1, endSample: 3, sampleRateHz: 16000),
      VadSegment(startSample: 4, endSample: 6, sampleRateHz: 16000),
    ]);

    expect(chunks, hasLength(2));

    final first = WavAudio.parse(chunks[0]);
    expect(first.sampleRateHz, 16000);
    expect(first.channels, 1);
    expect(first.bitsPerSample, 16);
    expect(first.sampleCount, 2);
    expect(chunks[0].length, 48);

    final second = WavAudio.parse(chunks[1]);
    expect(second.sampleRateHz, 16000);
    expect(second.channels, 1);
    expect(second.bitsPerSample, 16);
    expect(second.sampleCount, 2);
    expect(chunks[1].length, 48);
  });
}

Uint8List _pcmWav(Int16List samples, {required int sampleRateHz}) {
  final data = Uint8List.view(samples.buffer);
  final bytes = Uint8List(44 + data.length);
  final view = ByteData.sublistView(bytes);
  _writeAscii(bytes, 0, 'RIFF');
  view.setUint32(4, bytes.length - 8, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, sampleRateHz, Endian.little);
  view.setUint32(28, sampleRateHz * 2, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  view.setUint32(40, data.length, Endian.little);
  bytes.setRange(44, bytes.length, data);
  return bytes;
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  bytes.setRange(offset, offset + value.length, value.codeUnits);
}
