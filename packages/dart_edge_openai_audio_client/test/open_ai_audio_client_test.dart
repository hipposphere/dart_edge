import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_edge_audio/dart_edge_audio.dart';
import 'package:dart_edge_core/dart_edge_core.dart';
import 'package:dart_edge_openai_audio_client/dart_edge_openai_audio_client.dart';
import 'package:ffi/ffi.dart';
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

  test(
    'streams transport lease through audio finishing into transcription',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final receivedBody = Completer<Uint8List>();
      server.listen((request) async {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in request) {
          builder.add(chunk);
        }
        receivedBody.complete(builder.takeBytes());
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{'text': 'native stream'}));
        await request.response.close();
      });

      final client = await OpenAiAudioClient.open(
        OpenAiAudioClientConfig(
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          allowHttp: true,
        ),
      );
      final pool = NativeAudioPool(workerCount: 1, maxQueueSize: 1);
      final pcmPtr = calloc<Uint8>(1024);
      var leaseReleased = false;
      final lease = NativeBinaryPayloadLease.fromPointer(
        bytesPtr: pcmPtr,
        length: 1024,
        release: () {
          leaseReleased = true;
          calloc.free(pcmPtr);
        },
      );

      try {
        final session = pool.createPcm16StreamSession(inputSampleRateHz: 16000);
        session.addLease(lease);
        expect(leaseReleased, isTrue);

        final wav = await session.finish();
        expect(wav.contentLength, greaterThan(44));
        expect(pool.metrics.currentSpoolBytes, 0);

        final response = await client.transcribeNativeStream(
          body: wav.body,
          contentLength: wav.contentLength,
          request: const OpenAiAudioTranscriptionRequest(
            model: 'test-model',
            filename: 'recording.wav',
            contentType: 'audio/wav',
          ),
        );

        expect(response.text, 'native stream');
        expect(
          _containsBytes(await receivedBody.future, ascii.encode('RIFF')),
          isTrue,
        );
      } finally {
        if (!lease.isClosed) lease.close();
        client.dispose();
        await pool.close();
        await server.close(force: true);
      }
    },
  );

  test('cancels an in-flight provider operation', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    final respond = Completer<void>();
    server.listen((request) async {
      await request.drain<void>();
      received.complete();
      await respond.future;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(<String, Object?>{'text': 'too late'}));
      await request.response.close();
    });

    final client = await OpenAiAudioClient.open(
      OpenAiAudioClientConfig(
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        allowHttp: true,
      ),
    );
    try {
      final operation = client.startTranscribeBytes(
        bytes: Uint8List(1024),
        request: const OpenAiAudioTranscriptionRequest(
          model: 'test-model',
          filename: 'recording.wav',
          contentType: 'audio/wav',
        ),
      );
      await received.future;
      operation.cancel();
      respond.complete();

      await expectLater(
        operation.response,
        throwsA(isA<OpenAiAudioRequestCancelledException>()),
      );
      expect(operation.isCancelled, isTrue);
    } finally {
      if (!respond.isCompleted) respond.complete();
      client.dispose();
      await server.close(force: true);
    }
  });
}

bool _containsBytes(Uint8List haystack, List<int> needle) {
  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var matches = true;
    for (var index = 0; index < needle.length; index++) {
      if (haystack[offset + index] != needle[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
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
