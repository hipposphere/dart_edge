import 'dart:async';
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

  final wavBytes = options.file == null
      ? _pcmWav(Int16List(options.generatedSeconds * 16000))
      : await File(options.file!).readAsBytes();
  final wav = WavAudio.parse(wavBytes);
  if (wav.sampleRateHz != 16000 || wav.channels != 1) {
    stderr.writeln(
      'Expected 16 kHz mono WAV, got '
      '${wav.sampleRateHz} Hz / ${wav.channels} channel(s).',
    );
    exit(65);
  }

  final pcm = _readPcm16(wav);
  final result = await _runBenchmark(pcm: pcm, options: options);

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'package': 'dart_edge_vad',
      'benchmark': 'vad_throughput',
      'file': options.file ?? 'generated-silence-${options.generatedSeconds}s',
      'audio': {
        'sampleRateHz': wav.sampleRateHz,
        'channels': wav.channels,
        'samples': wav.sampleCount,
        'durationMs': (wav.sampleCount / wav.sampleRateHz * 1000).round(),
      },
      'workerCount': options.workerCount,
      'concurrency': options.concurrency,
      'iterations': options.iterations,
      'warmupIterations': options.warmupIterations,
      'result': result,
    }),
  );
}

Future<Map<String, Object?>> _runBenchmark({
  required Int16List pcm,
  required _Options options,
}) async {
  final vad = NativeVad(
    workerCount: options.workerCount,
    maxQueueSize: math.max(options.iterations, options.workerCount * 8),
  );
  try {
    await vad.initialize();
    await _runLimited(
      options.warmupIterations,
      options.concurrency,
      (_) => vad.detect(pcm16KhzMono: pcm, sampleRateHz: 16000),
    );

    final wall = Stopwatch()..start();
    final durations = await _runLimited<double>(
      options.iterations,
      options.concurrency,
      (_) async {
        final stopwatch = Stopwatch()..start();
        await vad.detect(pcm16KhzMono: pcm, sampleRateHz: 16000);
        stopwatch.stop();
        return stopwatch.elapsedMicroseconds / 1000;
      },
    );
    wall.stop();

    if (options.holdSeconds > 0) {
      await Future<void>.delayed(Duration(seconds: options.holdSeconds));
    }

    return {
      'mode': 'native',
      'wallDurationMs': _roundMs(wall.elapsedMicroseconds / 1000),
      'throughputPerSecond': _roundMs(
        options.iterations / (wall.elapsedMicroseconds / 1000000),
      ),
      'requestMs': _summary(durations).toJson(),
    };
  } finally {
    await vad.close();
  }
}

Future<List<T>> _runLimited<T>(
  int count,
  int concurrency,
  Future<T> Function(int index) fn,
) async {
  final results = List<T?>.filled(count, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      nextIndex += 1;
      if (index >= count) {
        return;
      }
      results[index] = await fn(index);
    }
  }

  await Future.wait([
    for (var i = 0; i < concurrency.clamp(1, count); i += 1) worker(),
  ]);
  return results.cast<T>();
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
Benchmark dart_edge_vad native throughput on 16 kHz mono WAV input.

Usage:
  dart run tool/vad_throughput_benchmark.dart [options]

Options:
  --file <path>             Optional 16 kHz mono WAV input.
  --generated-seconds <n>   Silence length when --file is omitted. Default: 10
  --worker-count <n>        Native worker count. Default: 4
  --concurrency <n>         Concurrent requests. Default: worker-count
  --iterations <n>          Measured requests. Default: max(40, concurrency * 8)
  --warmup <n>              Warmup requests. Default: worker-count
  --hold-seconds <n>        Keep process alive after measurement for external sampling. Default: 0
''');
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
    required this.workerCount,
    required this.concurrency,
    required this.iterations,
    required this.warmupIterations,
    required this.holdSeconds,
    required this.help,
  });

  final String? file;
  final int generatedSeconds;
  final int workerCount;
  final int concurrency;
  final int iterations;
  final int warmupIterations;
  final int holdSeconds;
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

    final workerCount = int.parse(
      values['worker-count'] ?? Platform.environment['VAD_WORKER_COUNT'] ?? '4',
    );
    final concurrency = int.parse(
      values['concurrency'] ??
          Platform.environment['VAD_CONCURRENCY'] ??
          '$workerCount',
    );

    return _Options(
      file: values['file'] ?? Platform.environment['AUDIO_FILE_PATH'],
      generatedSeconds: int.parse(values['generated-seconds'] ?? '10'),
      workerCount: workerCount,
      concurrency: concurrency,
      iterations: int.parse(
        values['iterations'] ??
            Platform.environment['VAD_ITERATIONS'] ??
            '${math.max(40, concurrency * 8)}',
      ),
      warmupIterations: int.parse(
        values['warmup'] ??
            Platform.environment['VAD_WARMUP_ITERATIONS'] ??
            '$workerCount',
      ),
      holdSeconds: int.parse(
        values['hold-seconds'] ??
            Platform.environment['VAD_HOLD_SECONDS'] ??
            '0',
      ),
      help: help,
    );
  }
}
