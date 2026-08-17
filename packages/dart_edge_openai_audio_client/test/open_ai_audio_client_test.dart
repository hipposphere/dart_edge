import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_edge_openai_audio_client/dart_edge_openai_audio_client.dart';
import 'package:test/test.dart';

void main() {
  test('sends bytes as an OpenAI-compatible multipart request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<_ReceivedRequest>();
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      received.complete(
        _ReceivedRequest(
          path: request.uri.path,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          testHeader: request.headers.value('x-test-header'),
          body: body,
        ),
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..headers.set('x-request-id', 'request-123')
        ..write(jsonEncode(<String, Object?>{'text': 'hello world'}));
      await request.response.close();
    });

    final client = await OpenAiAudioClient.open(
      OpenAiAudioClientConfig(
        baseUrl: 'http://127.0.0.1:${server.port}/openai/v1',
        apiKey: 'test-key',
        headers: const <String, String>{'x-test-header': 'present'},
        allowHttp: true,
      ),
    );
    try {
      final response = await client.transcribeBytes(
        bytes: Uint8List.fromList(utf8.encode('native-audio-payload')),
        request: const OpenAiAudioTranscriptionRequest(
          model: 'test-model',
          filename: 'recording.wav',
          contentType: 'audio/wav',
          language: 'en',
          additionalFields: <OpenAiAudioFormField>[
            OpenAiAudioFormField('vad_filter', 'true'),
          ],
        ),
      );
      expect(response.text, 'hello world');
      expect(response.requestId, 'request-123');

      final request = await received.future;
      expect(request.path, '/openai/v1/audio/transcriptions');
      expect(request.authorization, 'Bearer test-key');
      expect(request.testHeader, 'present');
      expect(request.body, contains('name="model"'));
      expect(request.body, contains('test-model'));
      expect(request.body, contains('name="language"'));
      expect(request.body, contains('name="vad_filter"'));
      expect(request.body, contains('native-audio-payload'));
    } finally {
      client.dispose();
      await server.close(force: true);
    }
  });

  test('rejects insecure endpoints unless explicitly allowed', () {
    expect(
      OpenAiAudioClient.open(
        const OpenAiAudioClientConfig(baseUrl: 'http://127.0.0.1:8000'),
      ),
      throwsArgumentError,
    );
  });

  test('exposes common JSON transcription text', () {
    const response = OpenAiAudioTranscriptionResponse(
      statusCode: 200,
      body: '{"text":"transcript"}',
    );
    expect(response.text, 'transcript');
  });
}

final class _ReceivedRequest {
  const _ReceivedRequest({
    required this.path,
    required this.authorization,
    required this.testHeader,
    required this.body,
  });

  final String path;
  final String? authorization;
  final String? testHeader;
  final String body;
}
