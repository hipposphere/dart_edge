import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_edge_vad/dart_edge_vad.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options.help) {
    _printUsage();
    return;
  }

  final bytes = options.file == null
      ? _pcmWav(Int16List(options.generatedSeconds * 16000))
      : await File(options.file!).readAsBytes();

  final parseStopwatch = Stopwatch()..start();
  final wav = WavAudio.parse(bytes);
  final pcm = _readPcm16(wav);
  parseStopwatch.stop();

  if (wav.sampleRateHz != 16000 || wav.channels != 1) {
    stderr.writeln(
      'Expected 16 kHz mono WAV, got '
      '${wav.sampleRateHz} Hz / ${wav.channels} channel(s).',
    );
    exit(65);
  }

  final vad = SileroVad(
    options: SileroVadOptions(
      threshold: options.threshold,
      minSpeechDuration: Duration(milliseconds: options.minSpeechMs),
      minSilenceDuration: Duration(milliseconds: options.minSilenceMs),
      speechPad: Duration(milliseconds: options.speechPadMs),
    ),
  );

  final cold = await _measureDetect(vad, pcm);
  for (var i = 0; i < options.warmup; i += 1) {
    await vad.detect(pcm16KhzMono: pcm, sampleRateHz: wav.sampleRateHz);
  }

  final facade = <double>[];
  VadResult? lastResult;
  for (var i = 0; i < options.iterations; i += 1) {
    final sample = await _measureDetect(vad, pcm);
    facade.add(sample.elapsedMs);
    lastResult = sample.result;
  }

  final nativeBuffer = NativePcm16Buffer(pcm.length)..samples.setAll(0, pcm);
  final native = <double>[];
  try {
    for (var i = 0; i < options.iterations; i += 1) {
      final sample = await _measureNativeDetect(vad, nativeBuffer);
      native.add(sample.elapsedMs);
    }
  } finally {
    nativeBuffer.close();
  }

  final worker = await SileroVadWorker.spawn(options: vad.options);
  final workerSequential = <double>[];
  try {
    for (var i = 0; i < options.iterations; i += 1) {
      final sample = await _measureWorkerDetect(worker, pcm);
      workerSequential.add(sample.elapsedMs);
    }
  } finally {
    await worker.close();
  }

  final streaming = <double>[];
  for (var i = 0; i < options.iterations; i += 1) {
    streaming.add(_measureStreaming(vad.options, pcm).elapsedMs);
  }

  final concurrentBatches = <Map<String, Object?>>[];
  for (final concurrency in options.concurrency) {
    final batchDurations = <double>[];
    final individualDurations = <double>[];

    for (var batch = 0; batch < options.concurrentBatches; batch += 1) {
      final batchStopwatch = Stopwatch()..start();
      final samples = await Future.wait([
        for (var i = 0; i < concurrency; i += 1) _measureDetect(vad, pcm),
      ]);
      batchStopwatch.stop();
      batchDurations.add(batchStopwatch.elapsedMicroseconds / 1000);
      individualDurations.addAll(samples.map((sample) => sample.elapsedMs));
    }

    concurrentBatches.add({
      'concurrency': concurrency,
      'batches': options.concurrentBatches,
      'batchWallMs': _summary(batchDurations).toJson(),
      'individualRequestMs': _summary(individualDurations).toJson(),
    });
  }

  final output = {
    'package': 'dart_edge_vad',
    'file': options.file ?? 'generated-silence-${options.generatedSeconds}s',
    'audio': {
      'sampleRateHz': wav.sampleRateHz,
      'channels': wav.channels,
      'samples': wav.sampleCount,
      'durationMs': (wav.sampleCount / wav.sampleRateHz * 1000).round(),
      'parseAndPcmReadMs': _roundMs(parseStopwatch.elapsedMicroseconds / 1000),
    },
    'vadOptions': {
      'threshold': options.threshold,
      'minSpeechMs': options.minSpeechMs,
      'minSilenceMs': options.minSilenceMs,
      'speechPadMs': options.speechPadMs,
    },
    'coldDetectMs': _roundMs(cold.elapsedMs),
    'sequential': {
      'warmup': options.warmup,
      'iterations': options.iterations,
      'facadeDetectMs': _summary(facade).toJson(),
      'nativeBufferDetectMs': _summary(native).toJson(),
      'workerDetectMs': _summary(workerSequential).toJson(),
      'streamingDetectMs': _summary(streaming).toJson(),
    },
    'concurrentFacade': concurrentBatches,
    'lastResult': {
      'hasSpeech': lastResult?.hasSpeech,
      'segments': lastResult?.segments.length,
    },
  };

  const encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(output));
}

Future<_VadSample> _measureDetect(SileroVad vad, Int16List pcm) async {
  final stopwatch = Stopwatch()..start();
  final result = await vad.detect(pcm16KhzMono: pcm, sampleRateHz: 16000);
  stopwatch.stop();
  return _VadSample(
    elapsedMs: stopwatch.elapsedMicroseconds / 1000,
    result: result,
  );
}

Future<_VadSample> _measureNativeDetect(
  SileroVad vad,
  NativePcm16Buffer pcm,
) async {
  final stopwatch = Stopwatch()..start();
  final result = await vad.detectNativeBuffer(
    pcm16KhzMono: pcm,
    sampleRateHz: 16000,
  );
  stopwatch.stop();
  return _VadSample(
    elapsedMs: stopwatch.elapsedMicroseconds / 1000,
    result: result,
  );
}

Future<_VadSample> _measureWorkerDetect(
  SileroVadWorker worker,
  Int16List pcm,
) async {
  final stopwatch = Stopwatch()..start();
  final result = await worker.detect(pcm16KhzMono: pcm, sampleRateHz: 16000);
  stopwatch.stop();
  return _VadSample(
    elapsedMs: stopwatch.elapsedMicroseconds / 1000,
    result: result,
  );
}

_Elapsed _measureStreaming(SileroVadOptions options, Int16List pcm) {
  final stopwatch = Stopwatch()..start();
  final stream = SileroVadStreamingSession(options: options);
  try {
    for (var offset = 0; offset < pcm.length; offset += 512) {
      final end = math.min(offset + 512, pcm.length);
      stream.addChunk(Int16List.sublistView(pcm, offset, end));
    }
    stream.finish();
  } finally {
    stream.close();
  }
  stopwatch.stop();
  return _Elapsed(stopwatch.elapsedMicroseconds / 1000);
}

Int16List _readPcm16(WavAudio wav) {
  final pcm = Int16List(wav.sampleCount);
  final view = ByteData.sublistView(wav.bytes);
  var byteOffset = wav.dataOffset;
  for (var i = 0; i < pcm.length; i += 1) {
    pcm[i] = view.getInt16(byteOffset, Endian.little);
    byteOffset += wav.blockAlign;
  }
  return pcm;
}

Uint8List _pcmWav(Int16List samples) {
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
  view.setUint32(24, 16000, Endian.little);
  view.setUint32(28, 16000 * 2, Endian.little);
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

void _printUsage() {
  stdout.writeln('''
Benchmark dart_edge_vad Silero detection on 16 kHz mono WAV input.

Usage:
  dart run tool/benchmark_dart_edge_vad.dart [--file path/to/audio.wav]

Options:
  --file <path>             Optional 16 kHz mono WAV input.
  --generated-seconds <n>   Silence length when --file is omitted. Default: 10
  --warmup <n>              Warmup detect calls before measuring. Default: 3
  --iterations <n>          Sequential measured calls per mode. Default: 20
  --concurrency <list>      Comma-separated facade concurrencies. Default: 1,2,4,8
  --batches <n>             Batches per concurrency value. Default: 5
  --threshold <number>      Silero speech threshold. Default: 0.5
  --min-speech-ms <n>       Minimum speech duration. Default: 0
  --min-silence-ms <n>      Minimum silence duration. Default: 3000
  --speech-pad-ms <n>       Speech padding. Default: 600
''');
}

final class _Elapsed {
  const _Elapsed(this.elapsedMs);

  final double elapsedMs;
}

final class _VadSample {
  const _VadSample({required this.elapsedMs, required this.result});

  final double elapsedMs;
  final VadResult result;
}

final class _Summary {
  const _Summary({
    required this.count,
    required this.min,
    required this.mean,
    required this.p50,
    required this.p95,
    required this.max,
  });

  final int count;
  final double min;
  final double mean;
  final double p50;
  final double p95;
  final double max;

  Map<String, Object?> toJson() => {
    'count': count,
    'min': _roundMs(min),
    'mean': _roundMs(mean),
    'p50': _roundMs(p50),
    'p95': _roundMs(p95),
    'max': _roundMs(max),
  };
}

_Summary _summary(List<double> values) {
  if (values.isEmpty) {
    return const _Summary(count: 0, min: 0, mean: 0, p50: 0, p95: 0, max: 0);
  }
  final sorted = [...values]..sort();
  final mean = values.reduce((sum, value) => sum + value) / values.length;
  return _Summary(
    count: values.length,
    min: sorted.first,
    mean: mean,
    p50: _percentile(sorted, 0.50),
    p95: _percentile(sorted, 0.95),
    max: sorted.last,
  );
}

double _percentile(List<double> sorted, double percentile) {
  final index = math.max(
    0,
    math.min(sorted.length - 1, (sorted.length * percentile).ceil() - 1),
  );
  return sorted[index];
}

double _roundMs(double value) => (value * 100).roundToDouble() / 100;

final class _Options {
  const _Options({
    required this.file,
    required this.generatedSeconds,
    required this.warmup,
    required this.iterations,
    required this.concurrency,
    required this.concurrentBatches,
    required this.threshold,
    required this.minSpeechMs,
    required this.minSilenceMs,
    required this.speechPadMs,
    required this.help,
  });

  final String? file;
  final int generatedSeconds;
  final int warmup;
  final int iterations;
  final List<int> concurrency;
  final int concurrentBatches;
  final double threshold;
  final int minSpeechMs;
  final int minSilenceMs;
  final int speechPadMs;
  final bool help;

  static _Options parse(List<String> args) {
    final values = <String, String>{};
    var help = false;
    for (var i = 0; i < args.length; i += 1) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        help = true;
        continue;
      }
      if (!arg.startsWith('--')) {
        throw FormatException('Unexpected positional argument: $arg');
      }
      final key = arg.substring(2);
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for --$key');
      }
      values[key] = args[++i];
    }

    return _Options(
      file: values['file'],
      generatedSeconds: int.parse(values['generated-seconds'] ?? '10'),
      warmup: int.parse(values['warmup'] ?? '3'),
      iterations: int.parse(values['iterations'] ?? '20'),
      concurrency: (values['concurrency'] ?? '1,2,4,8')
          .split(',')
          .map((value) => int.parse(value.trim()))
          .where((value) => value > 0)
          .toList(),
      concurrentBatches: int.parse(values['batches'] ?? '5'),
      threshold: double.parse(values['threshold'] ?? '0.5'),
      minSpeechMs: int.parse(values['min-speech-ms'] ?? '0'),
      minSilenceMs: int.parse(values['min-silence-ms'] ?? '3000'),
      speechPadMs: int.parse(values['speech-pad-ms'] ?? '600'),
      help: help,
    );
  }
}
