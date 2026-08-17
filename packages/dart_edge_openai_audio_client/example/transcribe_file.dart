import 'dart:io';

import 'package:dart_edge_openai_audio_client/dart_edge_openai_audio_client.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run example/transcribe_file.dart <audio-file>');
    exitCode = 64;
    return;
  }
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set OPENAI_API_KEY before running this example.');
    exitCode = 64;
    return;
  }

  final file = File(args.single);
  final client = await OpenAiAudioClient.open(
    OpenAiAudioClientConfig(apiKey: apiKey),
  );
  try {
    final response = await client.transcribeBytes(
      bytes: await file.readAsBytes(),
      request: OpenAiAudioTranscriptionRequest(
        model: 'gpt-transcribe',
        filename: file.uri.pathSegments.last,
      ),
    );
    stdout.writeln(response.text ?? response.body);
  } finally {
    client.dispose();
  }
}
