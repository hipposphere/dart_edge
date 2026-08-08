import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';

const _objectBytes = 18 * 1024 * 1024;
const _warmupDownloads = 2;
const _measuredDownloads = 16;

Future<void> main(List<String> arguments) async {
  final mode = arguments.singleOrNull;
  if (mode != 'dart' && mode != 'native') {
    stderr.writeln(
      'Usage: dart run tool/s3_http_stream_benchmark.dart <dart|native>',
    );
    exitCode = 64;
    return;
  }

  final bytes = Uint8List(_objectBytes);
  for (var index = 0; index < bytes.length; index += 1) {
    bytes[index] = index % 251;
  }

  final objectServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  objectServer.listen((request) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = bytes.length
      ..headers.contentType = ContentType('audio', 'wav')
      ..add(bytes);
    await request.response.close();
  });

  final s3 = await DartEdgeS3Client.open(
    S3ClientConfig(
      region: 'us-east-1',
      endpoint: 'http://127.0.0.1:${objectServer.port}',
      accessKeyId: 'benchmark',
      secretAccessKey: 'benchmark',
      forcePathStyle: true,
      allowHttp: true,
    ),
  );
  const object = S3ObjectRef(bucket: 'recordings', key: 'long-recording.wav');

  final app = DartEdge<void>(services: () {});
  app.get(
    '/recording',
    options: const RouteOptions(
      operationId: 'benchmarkRecordingStream',
      success: ResponseSpec.binary(contentType: 'audio/wav'),
    ),
    handler: (_) async {
      if (mode == 'native') {
        final result = await s3.getObjectNativeStream(object);
        return NativeBinaryStreamResponse(
          body: result.body,
          contentType: 'audio/wav',
          contentLength: result.metadata.contentLength,
        );
      }
      final result = await s3.getObjectStream(object);
      return BinaryStreamResponse(
        body: result.body,
        contentType: 'audio/wav',
        contentLength: result.metadata.contentLength,
        onDispose: result.close,
      );
    },
  );

  final server = await app.listen(port: 0);
  final client = HttpClient();
  final uri = Uri.http('127.0.0.1:${server.port}', '/recording');

  Future<void> download() async {
    final response = await (await client.getUrl(uri)).close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Unexpected HTTP status ${response.statusCode}.');
    }
    var received = 0;
    await for (final chunk in response) {
      received += chunk.length;
    }
    if (received != _objectBytes) {
      throw StateError('Received $received bytes instead of $_objectBytes.');
    }
  }

  try {
    for (var index = 0; index < _warmupDownloads; index += 1) {
      await download();
    }

    final rssBefore = ProcessInfo.currentRss;
    var peakRss = rssBefore;
    final sampler = Timer.periodic(const Duration(milliseconds: 2), (_) {
      peakRss = peakRss < ProcessInfo.currentRss
          ? ProcessInfo.currentRss
          : peakRss;
    });
    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < _measuredDownloads; index += 1) {
      await download();
    }
    stopwatch.stop();
    sampler.cancel();
    final rssAfter = ProcessInfo.currentRss;
    final transferredBytes = _objectBytes * _measuredDownloads;
    final seconds =
        stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;
    stdout.writeln(
      jsonEncode({
        'mode': mode,
        'objectMiB': _objectBytes / 1024 / 1024,
        'downloads': _measuredDownloads,
        'transferredMiB': transferredBytes / 1024 / 1024,
        'elapsedSeconds': seconds,
        'meanLatencyMs':
            stopwatch.elapsedMicroseconds / _measuredDownloads / 1000,
        'throughputMiBPerSecond': transferredBytes / 1024 / 1024 / seconds,
        'rssBeforeMiB': rssBefore / 1024 / 1024,
        'peakRssMiB': peakRss / 1024 / 1024,
        'rssAfterMiB': rssAfter / 1024 / 1024,
        'peakRssDeltaMiB': (peakRss - rssBefore) / 1024 / 1024,
        'activeStreamsAfter': DartEdgeS3Client.downloadStreamCounters.active,
      }),
    );
  } finally {
    client.close(force: true);
    await server.close();
    s3.dispose();
    await objectServer.close(force: true);
  }
}
