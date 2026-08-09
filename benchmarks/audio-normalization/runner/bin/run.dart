import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_edge_audio/dart_edge_audio.dart';
import 'package:dart_edge_audio/dart_edge_audio_testing.dart';
import 'package:dart_edge_vad/dart_edge_vad.dart';

Future<void> main(List<String> args) async {
  final options = _BenchmarkOptions.parse(args);
  final fixturesDir = Directory(options.fixturesDir);
  if (!fixturesDir.existsSync()) {
    throw StateError(
      'Missing audio fixtures at ${fixturesDir.path}. Run '
      '`cd packages/dart_edge_audio && '
      'dart run tool/download_audio_fixtures.dart` first.',
    );
  }

  await DartEdgeAudio.initialize();

  final results = <Map<String, Object?>>[];
  final vad = NativeVad();
  try {
    for (final fixture in audioFixtureManifest) {
      final file = File(fixture.pathIn(fixturesDir.path));
      if (!file.existsSync()) {
        throw StateError(
          'Missing ${fixture.fileName}. Run the fixture downloader first.',
        );
      }

      final bytes = await file.readAsBytes();
      for (var index = 0; index < options.warmups; index += 1) {
        await _measureFixtureBatch(vad, fixture, bytes, options.concurrency);
      }

      final runs = <_FixtureRun>[];
      for (var index = 0; index < options.iterations; index += 1) {
        runs.addAll(
          await _measureFixtureBatch(vad, fixture, bytes, options.concurrency),
        );
      }

      final result = _summarize(fixture, bytes.length, runs);
      results.add(result);
      stdout.writeln(
        '${fixture.format.padRight(4)} '
        'probe=${result['probeLatencyMs']}ms '
        'normalize=${result['normalizeLatencyMs']}ms '
        'waveform=${result['waveformNormalizeLatencyMs']}ms '
        'vad=${result['vadLatencyMs']}ms '
        'trim=${result['trimLatencyMs']}ms '
        'total=${result['totalLatencyMs']}ms '
        'rt=${result['realtimeFactor']}x '
        'out=${result['outputBytes']} bytes '
        'trimmed=${result['trimmedBytes']} bytes '
        'segments=${result['speechSegments']}',
      );
    }
  } finally {
    await vad.close();
    await DartEdgeAudio.close();
  }

  final report = <String, Object?>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'iterations': options.iterations,
    'warmups': options.warmups,
    'concurrency': options.concurrency,
    'audioBackend': 'native-pool',
    'fixturesDir': fixturesDir.path,
    'results': results,
  };

  if (options.jsonOut case final jsonOut?) {
    final file = File(jsonOut);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
  }
}

Future<_FixtureRun> _measureFixture(
  Vad vad,
  AudioFixture fixture,
  List<int> bytes,
) async {
  final probeWatch = Stopwatch()..start();
  final metadata = await DartEdgeAudio.probeBytes(
    Uint8List.fromList(bytes),
    fileNameHint: fixture.fileName,
    mimeTypeHint: fixture.mimeType,
  );
  probeWatch.stop();

  final normalizeWatch = Stopwatch()..start();
  final normalized = await DartEdgeAudio.convertBytes(
    AudioBytesConversionRequest(
      inputBytes: Uint8List.fromList(bytes),
      targetFormat: AudioTargetFormat.wavPcm16,
      targetSampleRate: 16000,
      channelLayout: AudioChannelLayout.mono,
      fileNameHint: fixture.fileName,
      mimeTypeHint: fixture.mimeType,
    ),
  );
  normalizeWatch.stop();

  final waveformNormalizeWatch = Stopwatch()..start();
  final normalizedWithWaveform = await DartEdgeAudio.convertBytes(
    AudioBytesConversionRequest(
      inputBytes: Uint8List.fromList(bytes),
      targetFormat: AudioTargetFormat.wavPcm16,
      targetSampleRate: 16000,
      channelLayout: AudioChannelLayout.mono,
      fileNameHint: fixture.fileName,
      mimeTypeHint: fixture.mimeType,
      waveform: const AudioWaveformSpec(),
    ),
  );
  waveformNormalizeWatch.stop();
  if (!_bytesEqual(normalized.bytes, normalizedWithWaveform.bytes) ||
      normalizedWithWaveform.waveform == null) {
    throw StateError(
      '${fixture.fileName} waveform conversion changed the WAV output.',
    );
  }

  final wav = WavAudio.parse(normalized.bytes);
  if (wav.sampleRateHz != 16000 ||
      wav.channels != 1 ||
      wav.bitsPerSample != 16) {
    throw StateError(
      '${fixture.fileName} did not normalize to mono 16 kHz PCM16 WAV.',
    );
  }

  final pcm16 = _readMonoPcm16(wav);
  final vadWatch = Stopwatch()..start();
  final vadResult = await vad.detect(
    pcm16KhzMono: pcm16,
    sampleRateHz: wav.sampleRateHz,
  );
  vadWatch.stop();

  final trimWatch = Stopwatch()..start();
  final trimmed = AudioTrimmer.trimBySegments(
    normalized.bytes,
    vadResult.segments,
  );
  trimWatch.stop();

  return _FixtureRun(
    duration: metadata.duration,
    probeLatency: probeWatch.elapsed,
    normalizeLatency: normalizeWatch.elapsed,
    waveformNormalizeLatency: waveformNormalizeWatch.elapsed,
    vadLatency: vadWatch.elapsed,
    trimLatency: trimWatch.elapsed,
    outputBytes: normalized.bytes.length,
    trimmedBytes: trimmed.length,
    speechSegments: vadResult.segments.length,
    speechSamples: vadResult.segments.fold<int>(
      0,
      (total, segment) => total + segment.lengthSamples,
    ),
  );
}

Future<List<_FixtureRun>> _measureFixtureBatch(
  Vad vad,
  AudioFixture fixture,
  List<int> bytes,
  int concurrency,
) {
  return Future.wait([
    for (var index = 0; index < concurrency; index += 1)
      _measureFixture(vad, fixture, bytes),
  ]);
}

Map<String, Object?> _summarize(
  AudioFixture fixture,
  int inputBytes,
  List<_FixtureRun> runs,
) {
  final representative = runs.first;
  final probe = _median(runs.map((run) => run.probeLatency));
  final normalize = _median(runs.map((run) => run.normalizeLatency));
  final waveformNormalize = _median(
    runs.map((run) => run.waveformNormalizeLatency),
  );
  final vad = _median(runs.map((run) => run.vadLatency));
  final trim = _median(runs.map((run) => run.trimLatency));
  final total = _median(runs.map((run) => run.totalLatency));
  final realtimeFactor =
      total.inMicroseconds / representative.duration.inMicroseconds;
  final speechDuration = Duration(
    microseconds: representative.speechSamples * 1000000 ~/ 16000,
  );

  return {
    'id': fixture.id,
    'format': fixture.format,
    'fileName': fixture.fileName,
    'inputBytes': inputBytes,
    'durationMs': representative.duration.inMilliseconds,
    'probeLatencyMs': _roundMicros(probe),
    'normalizeLatencyMs': _roundMicros(normalize),
    'waveformNormalizeLatencyMs': _roundMicros(waveformNormalize),
    'vadLatencyMs': _roundMicros(vad),
    'trimLatencyMs': _roundMicros(trim),
    'totalLatencyMs': _roundMicros(total),
    'outputBytes': representative.outputBytes,
    'trimmedBytes': representative.trimmedBytes,
    'speechSegments': representative.speechSegments,
    'speechDurationMs': speechDuration.inMilliseconds,
    'realtimeFactor': double.parse(realtimeFactor.toStringAsFixed(3)),
  };
}

bool _bytesEqual(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Int16List _readMonoPcm16(WavAudio wav) {
  final sampleCount = wav.sampleCount;
  final samples = Int16List(sampleCount);
  final view = ByteData.sublistView(wav.bytes);
  for (var index = 0; index < sampleCount; index += 1) {
    samples[index] = view.getInt16(
      wav.dataOffset + index * wav.blockAlign,
      Endian.little,
    );
  }
  return samples;
}

Duration _median(Iterable<Duration> values) {
  final sorted = values.toList()..sort((left, right) => left.compareTo(right));
  return sorted[sorted.length ~/ 2];
}

double _roundMicros(Duration value) {
  return double.parse((value.inMicroseconds / 1000).toStringAsFixed(3));
}

final class _FixtureRun {
  const _FixtureRun({
    required this.duration,
    required this.probeLatency,
    required this.normalizeLatency,
    required this.waveformNormalizeLatency,
    required this.vadLatency,
    required this.trimLatency,
    required this.outputBytes,
    required this.trimmedBytes,
    required this.speechSegments,
    required this.speechSamples,
  });

  final Duration duration;
  final Duration probeLatency;
  final Duration normalizeLatency;
  final Duration waveformNormalizeLatency;
  final Duration vadLatency;
  final Duration trimLatency;
  final int outputBytes;
  final int trimmedBytes;
  final int speechSegments;
  final int speechSamples;

  Duration get totalLatency =>
      probeLatency + normalizeLatency + vadLatency + trimLatency;
}

final class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.iterations,
    required this.warmups,
    required this.concurrency,
    required this.fixturesDir,
    this.jsonOut,
  });

  final int iterations;
  final int warmups;
  final int concurrency;
  final String fixturesDir;
  final String? jsonOut;

  static _BenchmarkOptions parse(List<String> args) {
    final iterations = _intOption(args, '--iterations') ?? 5;
    final warmups = _intOption(args, '--warmups') ?? 1;
    if (iterations < 1) {
      throw ArgumentError.value(
        iterations,
        'iterations',
        'Must be at least 1.',
      );
    }
    if (warmups < 0) {
      throw ArgumentError.value(warmups, 'warmups', 'Must not be negative.');
    }
    final concurrency = _intOption(args, '--concurrency') ?? 1;
    if (concurrency < 1) {
      throw ArgumentError.value(
        concurrency,
        'concurrency',
        'Must be at least 1.',
      );
    }

    return _BenchmarkOptions(
      iterations: iterations,
      warmups: warmups,
      concurrency: concurrency,
      fixturesDir:
          _optionValue(args, '--fixtures-dir') ??
          _resolveRepoRelativePath(defaultAudioFixtureCachePath),
      jsonOut: _optionValue(args, '--json-out'),
    );
  }
}

int? _intOption(List<String> args, String name) {
  final value = _optionValue(args, name);
  return value == null ? null : int.parse(value);
}

String? _optionValue(List<String> args, String name) {
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == name && index + 1 < args.length) {
      return args[index + 1];
    }
    if (arg.startsWith('$name=')) {
      return arg.substring(name.length + 1);
    }
  }
  return null;
}

String _resolveRepoRelativePath(String repoRelativePath) {
  var directory = Directory.current;
  while (true) {
    final candidate = File('${directory.path}/pubspec.yaml');
    final audioPackage = Directory(
      '${directory.path}/packages/dart_edge_audio',
    );
    if (candidate.existsSync() && audioPackage.existsSync()) {
      return '${directory.path}/$repoRelativePath';
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      return repoRelativePath;
    }
    directory = parent;
  }
}
