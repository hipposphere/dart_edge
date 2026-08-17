import 'dart:typed_data';

import 'package:dart_edge_audio/dart_edge_audio.dart';
import 'package:test/test.dart';

void main() {
  test('serializes M4A/AAC-LC output settings', () {
    final request = AudioBytesConversionRequest(
      inputBytes: Uint8List.fromList(const [1]),
      output: const AudioOutputSpec.m4aAacLc(bitRate: 64000),
    );

    expect(request.output.mimeType, 'audio/mp4');
    expect(request.output.fileExtension, 'm4a');
    expect(request.toJson()['targetFormat'], {
      'format': 'm4aAacLc',
      'bitRate': 64000,
    });
  });

  test('serializes FLAC output settings', () {
    final request = AudioBytesConversionRequest(
      inputBytes: Uint8List.fromList(const [1]),
      output: const AudioOutputSpec.flac(compressionLevel: 7),
    );

    expect(request.output.mimeType, 'audio/flac');
    expect(request.output.fileExtension, 'flac');
    expect(request.toJson()['targetFormat'], {
      'format': 'flac',
      'compressionLevel': 7,
    });
  });

  test('rejects invalid codec settings before native submission', () {
    expect(
      () => AudioBytesConversionRequest(
        inputBytes: Uint8List.fromList(const [1]),
        output: const AudioOutputSpec.m4aAacLc(bitRate: 7999),
      ),
      throwsRangeError,
    );
    expect(
      () => AudioBytesConversionRequest(
        inputBytes: Uint8List.fromList(const [1]),
        output: const AudioOutputSpec.flac(compressionLevel: 9),
      ),
      throwsRangeError,
    );
  });

  test('preserves legacy WAV request compatibility', () {
    final request = AudioBytesConversionRequest(
      inputBytes: Uint8List.fromList(const [1]),
      targetFormat: AudioTargetFormat.wavPcm24,
    );

    expect(request.output, isA<WavPcm24AudioOutputSpec>());
    expect(request.targetFormat, AudioTargetFormat.wavPcm24);
  });
}
