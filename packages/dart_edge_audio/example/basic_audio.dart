import 'dart:io';

import 'package:dart_edge_audio/dart_edge_audio.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run example/basic_audio.dart <input-audio> <output-wav>',
    );
    exitCode = 64;
    return;
  }

  final metadata = await DartEdgeAudio.probeFile(args[0]);
  stdout.writeln(
    'Input: container=${metadata.container}, codec=${metadata.codec}, '
    'sampleRate=${metadata.sampleRate}, channels=${metadata.channelCount}',
  );

  final converted = await DartEdgeAudio.convertFile(
    AudioFileConversionRequest(
      inputPath: args[0],
      outputPath: args[1],
      targetFormat: AudioTargetFormat.wavPcm16,
      targetSampleRate: 16000,
      channelLayout: AudioChannelLayout.mono,
      overwriteExisting: true,
    ),
  );

  stdout.writeln(
    'Output: ${converted.outputPath} '
    '(${converted.metadata.sampleRate} Hz, ${converted.metadata.channelCount} ch)',
  );
}
