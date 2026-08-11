import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_edge_audio/dart_edge_audio.dart';
import 'package:dart_edge_native_bridge/dart_edge_native_bridge.dart'
    as core_ffi;
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

void main() {
  group('probeFile', () {
    final cases = <_FixtureCase>[
      const _FixtureCase(
        path: 'test/fixtures/tone.wav',
        container: 'wav',
        codec: 'pcm_s16le',
      ),
      const _FixtureCase(
        path: 'test/fixtures/tone.mp3',
        container: 'mp3',
        codec: 'mp3',
      ),
      const _FixtureCase(
        path: 'test/fixtures/tone.flac',
        container: 'flac',
        codec: 'flac',
      ),
      const _FixtureCase(
        path: 'test/fixtures/tone.ogg',
        container: 'ogg',
        codec: 'vorbis',
      ),
    ];

    for (final fixture in cases) {
      test('reads ${fixture.container} metadata', () async {
        final metadata = await DartEdgeAudio.probeFile(fixture.resolvedPath);
        _expectFixtureMetadata(
          metadata,
          container: fixture.container,
          codec: fixture.codec,
        );
      });
    }
  });

  test('probeFile supports explicit shallow and full modes', () async {
    final toneMp3 = _fixturePath('tone.mp3');
    final shallow = await DartEdgeAudio.probeFile(
      toneMp3,
      mode: AudioProbeMode.shallow,
    );
    final adaptive = await DartEdgeAudio.probeFile(toneMp3);
    final full = await DartEdgeAudio.probeFile(
      toneMp3,
      mode: AudioProbeMode.full,
    );

    expect(shallow.container, 'mp3');
    expect(shallow.codec, 'mp3');
    expect(shallow.sampleRate, 44100);
    expect(shallow.channelCount, 2);
    expect(shallow.duration.inMilliseconds, inInclusiveRange(600, 900));
    expect(adaptive.duration, shallow.duration);
    expect(full.duration.inMilliseconds, inInclusiveRange(600, 900));
  });

  group('probeBytes', () {
    final cases = <_FixtureCase>[
      const _FixtureCase(
        path: 'test/fixtures/tone.wav',
        container: 'wav',
        codec: 'pcm_s16le',
        mimeType: 'audio/wav',
      ),
      const _FixtureCase(
        path: 'test/fixtures/tone.mp3',
        container: 'mp3',
        codec: 'mp3',
        mimeType: 'audio/mpeg',
      ),
      const _FixtureCase(
        path: 'test/fixtures/tone.flac',
        container: 'flac',
        codec: 'flac',
        mimeType: 'audio/flac',
      ),
      const _FixtureCase(
        path: 'test/fixtures/tone.ogg',
        container: 'ogg',
        codec: 'vorbis',
        mimeType: 'audio/ogg',
      ),
    ];

    for (final fixture in cases) {
      test('reads ${fixture.container} metadata from bytes', () async {
        final bytes = await File(fixture.resolvedPath).readAsBytes();
        final metadata = await DartEdgeAudio.probeBytes(
          bytes,
          fileNameHint: fixture.fileName,
          mimeTypeHint: fixture.mimeType,
        );
        _expectFixtureMetadata(
          metadata,
          container: fixture.container,
          codec: fixture.codec,
        );
      });
    }
  });

  test(
    'probeBytes adaptive uses shallow metadata when duration is available',
    () async {
      final bytes = await File(_fixturePath('tone.wav')).readAsBytes();
      final shallow = await DartEdgeAudio.probeBytes(
        bytes,
        fileNameHint: 'tone.wav',
        mimeTypeHint: 'audio/wav',
        mode: AudioProbeMode.shallow,
      );
      final adaptive = await DartEdgeAudio.probeBytes(
        bytes,
        fileNameHint: 'tone.wav',
        mimeTypeHint: 'audio/wav',
      );

      expect(shallow.container, 'wav');
      expect(shallow.codec, 'pcm_s16le');
      expect(shallow.duration.inMilliseconds, inInclusiveRange(600, 900));
      expect(shallow.tags['title'], 'Dart Edge Fixture');
      expect(adaptive.duration, shallow.duration);
    },
  );

  group('probeNativeBytes', () {
    final cases = <_FixtureCase>[
      const _FixtureCase(
        path: 'test/fixtures/tone.wav',
        container: 'wav',
        codec: 'pcm_s16le',
        mimeType: 'audio/wav',
      ),
      const _FixtureCase(
        path: 'test/fixtures/tone.mp3',
        container: 'mp3',
        codec: 'mp3',
        mimeType: 'audio/mpeg',
      ),
    ];

    for (final fixture in cases) {
      test(
        'reads ${fixture.container} metadata from borrowed native bytes',
        () async {
          final bytes = await File(fixture.resolvedPath).readAsBytes();
          final nativeBytes = _allocateNativeBytes(bytes);
          addTearDown(nativeBytes.dispose);

          final metadata = await DartEdgeAudio.probeNativeBytes(
            nativeBytes.view,
            fileNameHint: fixture.fileName,
            mimeTypeHint: fixture.mimeType,
          );
          _expectFixtureMetadata(
            metadata,
            container: fixture.container,
            codec: fixture.codec,
          );
        },
      );
    }
  });

  test('convertFile writes normalized wav output', () async {
    final tempDir = await Directory.systemTemp.createTemp('dart_edge_audio_');
    addTearDown(() => tempDir.delete(recursive: true));

    final outputPath = '${tempDir.path}/converted.wav';
    final result = await DartEdgeAudio.convertFile(
      AudioFileConversionRequest(
        inputPath: _fixturePath('tone.mp3'),
        outputPath: outputPath,
        targetFormat: AudioTargetFormat.wavPcm16,
        targetSampleRate: 16000,
        channelLayout: AudioChannelLayout.mono,
      ),
    );

    expect(result.outputPath, outputPath);
    expect(result.mimeType, 'audio/wav');
    expect(result.metadata.container, 'wav');
    expect(result.metadata.codec, 'pcm_s16le');
    expect(result.metadata.sampleRate, 16000);
    expect(result.metadata.channelCount, 1);
    expect(result.metadata.bitDepth, 16);
    expect(File(outputPath).existsSync(), isTrue);

    final probed = await DartEdgeAudio.probeFile(outputPath);
    expect(probed.container, 'wav');
    expect(probed.codec, 'pcm_s16le');
    expect(probed.sampleRate, 16000);
    expect(probed.channelCount, 1);
    expect(probed.bitDepth, 16);
  });

  test('convertBytes returns wav bytes and metadata', () async {
    final input = await File(_fixturePath('tone.flac')).readAsBytes();

    final result = await DartEdgeAudio.convertBytes(
      AudioBytesConversionRequest(
        inputBytes: input,
        targetFormat: AudioTargetFormat.wavPcm24,
        targetSampleRate: 48000,
        channelLayout: AudioChannelLayout.stereo,
        fileNameHint: 'tone.flac',
        mimeTypeHint: 'audio/flac',
      ),
    );

    expect(result.bytes, isNotEmpty);
    expect(result.mimeType, 'audio/wav');
    expect(result.metadata.container, 'wav');
    expect(result.metadata.codec, 'pcm_s24le');
    expect(result.metadata.sampleRate, 48000);
    expect(result.metadata.channelCount, 2);
    expect(result.metadata.bitDepth, 24);

    final probed = await DartEdgeAudio.probeBytes(
      result.bytes,
      fileNameHint: 'converted.wav',
      mimeTypeHint: 'audio/wav',
    );
    expect(probed.container, 'wav');
    expect(probed.codec, 'pcm_s24le');
    expect(probed.sampleRate, 48000);
    expect(probed.channelCount, 2);
    expect(probed.bitDepth, 24);
  });

  test(
    'convertBytes optionally returns signed multi-resolution waveform',
    () async {
      final input = await File(_fixturePath('tone.wav')).readAsBytes();
      final withoutWaveform = await DartEdgeAudio.convertBytes(
        AudioBytesConversionRequest(
          inputBytes: input,
          targetFormat: AudioTargetFormat.wavPcm16,
          targetSampleRate: 16000,
          channelLayout: AudioChannelLayout.mono,
          fileNameHint: 'tone.wav',
        ),
      );
      final withWaveform = await DartEdgeAudio.convertBytes(
        AudioBytesConversionRequest(
          inputBytes: input,
          targetFormat: AudioTargetFormat.wavPcm16,
          targetSampleRate: 16000,
          channelLayout: AudioChannelLayout.mono,
          fileNameHint: 'tone.wav',
          waveform: const AudioWaveformSpec(
            baseInterval: Duration(milliseconds: 10),
            levelFactors: [1, 4, 16],
          ),
        ),
      );

      expect(withWaveform.bytes, withoutWaveform.bytes);
      expect(withoutWaveform.waveform, isNull);
      final waveform = withWaveform.waveform;
      expect(waveform, isNotNull);
      expect(waveform!.baseInterval, const Duration(milliseconds: 10));
      expect(waveform.levels.map((level) => level.factor), [1, 4, 16]);
      expect(waveform.levels.map((level) => level.interval), [
        const Duration(milliseconds: 10),
        const Duration(milliseconds: 40),
        const Duration(milliseconds: 160),
      ]);
      expect(waveform.levels.first.peaks, isA<Int8List>());
      expect(waveform.levels.first.peaks, isNotEmpty);
      expect(waveform.levels.first.peaks.length.isEven, isTrue);
      expect(waveform.levels.first.peaks.any((peak) => peak < 0), isTrue);
      expect(waveform.levels.first.peaks.any((peak) => peak > 0), isTrue);
    },
  );

  test(
    'analyzeWaveform returns peaks without converted audio output',
    () async {
      final input = await File(_fixturePath('tone.wav')).readAsBytes();
      final result = await DartEdgeAudio.analyzeWaveform(
        AudioWaveformAnalysisRequest(
          inputBytes: input,
          targetSampleRate: 16000,
          channelLayout: AudioChannelLayout.mono,
          fileNameHint: 'tone.wav',
          waveform: const AudioWaveformSpec(
            baseInterval: Duration(milliseconds: 20),
            levelFactors: [1],
          ),
        ),
      );

      expect(result.metadata.sampleRate, 16000);
      expect(result.metadata.channelCount, 1);
      expect(result.waveform.levels, hasLength(1));
      expect(
        result.waveform.levels.single.interval,
        const Duration(milliseconds: 20),
      );
      expect(result.waveform.levels.single.peaks, isNotEmpty);
    },
  );

  test('streaming waveform is stable across Dart-managed chunks', () {
    final pcm16 = _pcm16Le([
      ...List.filled(10, -32768),
      ...List.filled(10, 32767),
      ...List.filled(5, 0),
    ]);
    final session = NativeAudioWaveformSession(
      sampleRateHz: 1000,
      waveform: const AudioWaveformSpec(
        baseInterval: Duration(milliseconds: 10),
        levelFactors: [1, 2],
      ),
    );
    addTearDown(session.close);

    session.addPcm16(Uint8List.sublistView(pcm16, 0, 12));
    session.addPcm16(Uint8List.sublistView(pcm16, 12));
    final result = session.finish();

    expect(result.sampleRateHz, 1000);
    expect(result.channelCount, 1);
    expect(result.frameCount, 25);
    expect(result.duration, const Duration(milliseconds: 25));
    expect(result.waveform.levels[0].peaks, [-127, -127, 127, 127, 0, 0]);
    expect(result.waveform.levels[1].peaks, [-127, 127, 0, 0]);
    expect(() => session.addPcm16(Uint8List(0)), throwsStateError);
  });

  test('streaming waveform accepts borrowed native PCM without a copy', () {
    final pcm16 = _pcm16Le([
      ...List.filled(10, -16384),
      ...List.filled(10, 16384),
    ]);
    final nativePcm = calloc<Uint8>(pcm16.length);
    nativePcm.asTypedList(pcm16.length).setAll(0, pcm16);
    addTearDown(() => calloc.free(nativePcm));
    final session = NativeAudioWaveformSession(
      sampleRateHz: 1000,
      waveform: const AudioWaveformSpec(
        baseInterval: Duration(milliseconds: 10),
        levelFactors: [1],
      ),
    );
    addTearDown(session.close);

    session.addNativePcm16(
      pcm16LeBytesPtr: nativePcm,
      byteLength: pcm16.length,
    );
    final result = session.finish();

    expect(result.frameCount, 20);
    expect(result.waveform.levels.single.peaks, [-64, -64, 64, 64]);
  });

  test('streaming waveform rejects incomplete PCM frames', () {
    final session = NativeAudioWaveformSession(sampleRateHz: 16000);
    addTearDown(session.close);

    expect(() => session.addPcm16(Uint8List(1)), throwsArgumentError);
  });

  test('convertNativeBytes returns wav bytes and metadata', () async {
    final input = await File(_fixturePath('tone.flac')).readAsBytes();
    final nativeBytes = _allocateNativeBytes(input);
    addTearDown(nativeBytes.dispose);

    final result = await DartEdgeAudio.convertNativeBytes(
      bytes: nativeBytes.view,
      targetFormat: AudioTargetFormat.wavPcm16,
      targetSampleRate: 16000,
      channelLayout: AudioChannelLayout.mono,
      fileNameHint: 'tone.flac',
      mimeTypeHint: 'audio/flac',
    );

    expect(result.bytes, isNotEmpty);
    expect(result.mimeType, 'audio/wav');
    expect(result.metadata.container, 'wav');
    expect(result.metadata.codec, 'pcm_s16le');
    expect(result.metadata.sampleRate, 16000);
    expect(result.metadata.channelCount, 1);
    expect(result.metadata.bitDepth, 16);
  });

  test('initialize warms and reuses a shared native audio pool', () async {
    await DartEdgeAudio.initialize();
    addTearDown(DartEdgeAudio.close);

    final input = await File(_fixturePath('tone.mp3')).readAsBytes();
    final metadata = await DartEdgeAudio.probeBytes(
      input,
      fileNameHint: 'tone.mp3',
      mimeTypeHint: 'audio/mpeg',
    );

    expect(metadata.container, 'mp3');
    expect(metadata.codec, 'mp3');

    final converted = await DartEdgeAudio.convertBytes(
      AudioBytesConversionRequest(
        inputBytes: input,
        targetFormat: AudioTargetFormat.wavPcm16,
        targetSampleRate: 16000,
        channelLayout: AudioChannelLayout.mono,
        fileNameHint: 'tone.mp3',
        mimeTypeHint: 'audio/mpeg',
      ),
    );

    expect(converted.mimeType, 'audio/wav');
    expect(converted.metadata.sampleRate, 16000);
    expect(converted.metadata.channelCount, 1);
  });

  test('probeFile surfaces missing-file errors', () async {
    await expectLater(
      () => DartEdgeAudio.probeFile(_fixturePath('missing.mp3')),
      throwsA(isA<StateError>()),
    );
  });

  test('probeBytes surfaces invalid data errors', () async {
    await expectLater(
      () => DartEdgeAudio.probeBytes(
        Uint8List.fromList([0, 1, 2, 3]),
        fileNameHint: 'invalid.mp3',
        mimeTypeHint: 'audio/mpeg',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('convertFile respects overwrite protection', () async {
    final tempDir = await Directory.systemTemp.createTemp('dart_edge_audio_');
    addTearDown(() => tempDir.delete(recursive: true));

    final outputFile = File('${tempDir.path}/existing.wav');
    await outputFile.writeAsBytes([1, 2, 3, 4]);

    await expectLater(
      () => DartEdgeAudio.convertFile(
        AudioFileConversionRequest(
          inputPath: _fixturePath('tone.mp3'),
          outputPath: outputFile.path,
          targetFormat: AudioTargetFormat.wavPcm16,
          overwriteExisting: false,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('convertBytes rejects empty inputs before native work', () async {
    await expectLater(
      () => DartEdgeAudio.convertBytes(
        AudioBytesConversionRequest(
          inputBytes: Uint8List(0),
          targetFormat: AudioTargetFormat.wavPcm16,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('concatenateStreams rejects empty inputs before native work', () async {
    await expectLater(
      () => DartEdgeAudio.concatenateStreams(
        inputs: const [],
        targetFormat: AudioTargetFormat.wavPcm16,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'probeNativeBytes rejects empty native inputs before native work',
    () async {
      final nativeBytes = calloc<core_ffi.NativeBytes>();
      addTearDown(() => calloc.free(nativeBytes));

      await expectLater(
        () => DartEdgeAudio.probeNativeBytes(nativeBytes.ref),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'convertNativeBytes rejects empty native inputs before native work',
    () async {
      final nativeBytes = calloc<core_ffi.NativeBytes>();
      addTearDown(() => calloc.free(nativeBytes));

      await expectLater(
        () => DartEdgeAudio.convertNativeBytes(
          bytes: nativeBytes.ref,
          targetFormat: AudioTargetFormat.wavPcm16,
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );
}

Uint8List _pcm16Le(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < samples.length; index += 1) {
    data.setInt16(index * 2, samples[index], Endian.little);
  }
  return bytes;
}

final class _FixtureCase {
  const _FixtureCase({
    required this.path,
    required this.container,
    required this.codec,
    this.mimeType,
  });

  final String path;
  final String container;
  final String codec;
  final String? mimeType;

  String get fileName => path.split('/').last;

  String get resolvedPath => _fixturePath(fileName);
}

String _fixturePath(String fileName) {
  final packageFixture = File(
    'packages/dart_edge_audio/test/fixtures/$fileName',
  );
  if (packageFixture.existsSync()) {
    return packageFixture.path;
  }
  return 'test/fixtures/$fileName';
}

void _expectFixtureMetadata(
  AudioMetadata metadata, {
  required String container,
  required String codec,
}) {
  expect(metadata.container, container);
  expect(metadata.codec, codec);
  expect(metadata.sampleRate, 44100);
  expect(metadata.channelCount, 2);
  expect(metadata.duration.inMilliseconds, inInclusiveRange(600, 900));
  expect(metadata.tags['title'], 'Dart Edge Fixture');
  expect(metadata.tags['artist'], 'Codex');
}

final class _AllocatedNativeBytes {
  _AllocatedNativeBytes._(this._storage, this._bytes);

  final Pointer<core_ffi.NativeBytes> _storage;
  final Pointer<Uint8> _bytes;
  var _disposed = false;

  core_ffi.NativeBytes get view => _storage.ref;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    calloc.free(_bytes);
    calloc.free(_storage);
  }
}

_AllocatedNativeBytes _allocateNativeBytes(Uint8List bytes) {
  final storage = calloc<core_ffi.NativeBytes>();
  final nativeBytes = calloc<Uint8>(bytes.length);
  nativeBytes.asTypedList(bytes.length).setAll(0, bytes);
  storage.ref
    ..ptr = nativeBytes
    ..len = bytes.length;
  return _AllocatedNativeBytes._(storage, nativeBytes);
}
