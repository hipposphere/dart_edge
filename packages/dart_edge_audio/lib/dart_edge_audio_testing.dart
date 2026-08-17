/// Test fixture metadata for audio probing and normalization checks.
///
/// This library is intended for package tests, benchmark runners, and local
/// verification tooling. It is not part of the app-facing audio API.
library;

/// Default location for cached internet audio fixtures.
const defaultAudioFixtureCachePath =
    'packages/dart_edge_audio/.dart_tool/audio_fixtures';

/// Pinned public audio files used by normalization integration tests.
const audioFixtureManifest = <AudioFixture>[
  AudioFixture(
    id: 'mp3_voice',
    format: 'mp3',
    fileName: 'voice-sample.mp3',
    url: 'https://sample-files.com/downloads/audio/mp3/voice-sample.mp3',
    sha256: '8b507743c84ffc98ab802ecd93cf72e3ffa1c4495616f12dd1d5da209ae5d43e',
    mimeType: 'audio/mpeg',
    expectedContainer: 'mp3',
    expectedCodec: 'mp3',
    expectedSampleRate: 44100,
    expectedChannelCount: 1,
    minDuration: Duration(seconds: 25),
    maxDuration: Duration(seconds: 28),
  ),
  AudioFixture(
    id: 'aac_sample',
    format: 'aac',
    fileName: 'sample3.aac',
    url: 'https://filesamples.com/samples/audio/aac/sample3.aac',
    sha256: 'ce1437d23dda72210d92d756227ca05825ba990a1500a7bdfe960881abd12532',
    mimeType: 'audio/x-hx-aac-adts',
    expectedContainer: 'aac',
    expectedCodec: 'aac',
    minDuration: Duration(seconds: 104),
    maxDuration: Duration(seconds: 107),
  ),
  AudioFixture(
    id: 'wav_voice',
    format: 'wav',
    fileName: 'voice-sample.wav',
    url: 'https://sample-files.com/downloads/audio/wav/voice-sample.wav',
    sha256: '826bdd52ec02602d2e5bc03cb9dd209c16ff943aa7feda848f5bea822a097d4e',
    mimeType: 'audio/wav',
    expectedContainer: 'wav',
    expectedCodec: 'pcm_s16le',
    expectedSampleRate: 44100,
    expectedChannelCount: 1,
    expectedBitDepth: 16,
    minDuration: Duration(seconds: 25),
    maxDuration: Duration(seconds: 28),
  ),
  AudioFixture(
    id: 'm4a_voice',
    format: 'm4a',
    fileName: 'voice-sample-96kbps.m4a',
    url: 'https://sample-files.com/downloads/audio/m4a/voice-sample-96kbps.m4a',
    sha256: '5e10b392fca583bfea952a5830cfb162d651be3b3aa0789f786f2ca711c395b9',
    mimeType: 'audio/mp4',
    expectedContainer: 'm4a',
    expectedCodec: 'aac',
    expectedSampleRate: 44100,
    expectedChannelCount: 1,
    minDuration: Duration(seconds: 25),
    maxDuration: Duration(seconds: 28),
  ),
  AudioFixture(
    id: 'flac_voice',
    format: 'flac',
    fileName: 'voice-sample-44100hz-16bit.flac',
    url: 'https://sample-files.com/downloads/audio/flac/voice-sample-44100hz-16bit.flac',
    sha256: '9ba6407a468265f05b6e68eda800583e0be202e378552981b5d1ddf3e70de202',
    mimeType: 'audio/flac',
    expectedContainer: 'flac',
    expectedCodec: 'flac',
    expectedSampleRate: 44100,
    expectedChannelCount: 1,
    expectedBitDepth: 16,
    minDuration: Duration(seconds: 25),
    maxDuration: Duration(seconds: 28),
  ),
  AudioFixture(
    id: 'ogg_voice',
    format: 'ogg',
    fileName: 'voice-sample.ogg',
    url: 'https://sample-files.com/downloads/audio/ogg/voice-sample.ogg',
    sha256: '9ff4938d52efb57b31d60d77055f678a0fd9f43d865687554249e7baec95e40a',
    mimeType: 'audio/ogg',
    expectedContainer: 'ogg',
    expectedCodec: 'vorbis',
    expectedSampleRate: 44100,
    expectedChannelCount: 1,
    minDuration: Duration(seconds: 19),
    maxDuration: Duration(seconds: 21),
  ),
];

/// One pinned audio fixture.
final class AudioFixture {
  const AudioFixture({
    required this.id,
    required this.format,
    required this.fileName,
    required this.url,
    required this.sha256,
    required this.mimeType,
    required this.expectedContainer,
    required this.expectedCodec,
    required this.minDuration,
    required this.maxDuration,
    this.expectedSampleRate,
    this.expectedChannelCount,
    this.expectedBitDepth,
  });

  final String id;
  final String format;
  final String fileName;
  final String url;
  final String sha256;
  final String mimeType;
  final String expectedContainer;
  final String expectedCodec;
  final Duration minDuration;
  final Duration maxDuration;
  final int? expectedSampleRate;
  final int? expectedChannelCount;
  final int? expectedBitDepth;

  String pathIn(String cachePath) => '$cachePath/$fileName';
}
