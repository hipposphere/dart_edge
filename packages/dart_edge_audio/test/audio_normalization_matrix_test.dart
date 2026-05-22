import 'dart:io';

import 'package:dart_edge_audio/dart_edge_audio.dart';
import 'package:dart_edge_audio/dart_edge_audio_testing.dart';
import 'package:dart_edge_vad/dart_edge_vad.dart';
import 'package:test/test.dart';

void main() {
  group('internet fixture normalization matrix', () {
    for (final fixture in audioFixtureManifest) {
      test(
        '${fixture.format} probes and normalizes to VAD-ready WAV',
        () async {
          final file = File(fixture.pathIn(_fixtureCachePath()));
          if (!file.existsSync()) {
            markTestSkipped(
              'Missing ${fixture.fileName}. Run '
              '`cd packages/dart_edge_audio && '
              'dart run tool/download_audio_fixtures.dart` first.',
            );
            return;
          }

          final bytes = await file.readAsBytes();
          final metadata = await DartEdgeAudio.probeBytes(
            bytes,
            fileNameHint: fixture.fileName,
            mimeTypeHint: fixture.mimeType,
          );

          expect(metadata.container, fixture.expectedContainer);
          expect(metadata.codec, fixture.expectedCodec);
          if (fixture.expectedSampleRate case final sampleRate?) {
            expect(metadata.sampleRate, sampleRate);
          }
          if (fixture.expectedChannelCount case final channelCount?) {
            expect(metadata.channelCount, channelCount);
          }
          if (fixture.expectedBitDepth case final bitDepth?) {
            expect(metadata.bitDepth, bitDepth);
          }
          expect(metadata.duration, greaterThanOrEqualTo(fixture.minDuration));
          expect(metadata.duration, lessThanOrEqualTo(fixture.maxDuration));

          final normalized = await DartEdgeAudio.convertBytes(
            AudioBytesConversionRequest(
              inputBytes: bytes,
              targetFormat: AudioTargetFormat.wavPcm16,
              targetSampleRate: 16000,
              channelLayout: AudioChannelLayout.mono,
              fileNameHint: fixture.fileName,
              mimeTypeHint: fixture.mimeType,
            ),
          );

          expect(normalized.mimeType, 'audio/wav');
          expect(normalized.metadata.container, 'wav');
          expect(normalized.metadata.codec, 'pcm_s16le');
          expect(normalized.metadata.sampleRate, 16000);
          expect(normalized.metadata.channelCount, 1);
          expect(normalized.metadata.bitDepth, 16);
          expect(normalized.bytes, isNotEmpty);

          final wav = WavAudio.parse(normalized.bytes);
          expect(wav.sampleRateHz, 16000);
          expect(wav.channels, 1);
          expect(wav.bitsPerSample, 16);
          expect(wav.sampleCount, greaterThan(0));
        },
      );
    }
  });
}

String _fixtureCachePath() {
  final override = Platform.environment['DART_EDGE_AUDIO_FIXTURES'];
  if (override != null && override.isNotEmpty) {
    return override;
  }
  return _resolveRepoRelativePath(defaultAudioFixtureCachePath);
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
