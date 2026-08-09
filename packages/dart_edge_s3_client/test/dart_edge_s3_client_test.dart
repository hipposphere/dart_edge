import 'dart:io';
import 'dart:typed_data';

import 'package:dart_edge_http_server/dart_edge_http_server.dart';
import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';
import 'package:dart_edge_s3_client/src/native/dart_edge_s3_client_native.dart';
import 'package:test/test.dart';

void main() {
  test('loads the native bundled asset', () {
    expect(DartEdgeS3ClientNative.abiVersion, greaterThanOrEqualTo(6));
  });

  test('closes native download streams on close and client disposal', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = 3
        ..headers.contentType = ContentType.binary
        ..add(const <int>[1, 2, 3]);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final client = await DartEdgeS3Client.open(
      S3ClientConfig(
        region: 'us-east-1',
        endpoint: 'http://127.0.0.1:${server.port}',
        accessKeyId: 'test',
        secretAccessKey: 'test',
        forcePathStyle: true,
        allowHttp: true,
      ),
    );
    addTearDown(client.dispose);
    const object = S3ObjectRef(bucket: 'recordings', key: 'sample.wav');
    final baseline = DartEdgeS3Client.downloadStreamCounters;

    final unlistened = await client.getObjectStream(object);
    expect(DartEdgeS3Client.downloadStreamCounters.active, baseline.active + 1);
    await unlistened.close();
    await unlistened.close();
    var counters = DartEdgeS3Client.downloadStreamCounters;
    expect(counters.active, baseline.active);
    expect(counters.started, baseline.started + 1);
    expect(counters.canceled, baseline.canceled + 1);

    final consumed = await client.getObjectStream(object);
    expect(await consumed.body.expand((chunk) => chunk).toList(), <int>[
      1,
      2,
      3,
    ]);
    counters = DartEdgeS3Client.downloadStreamCounters;
    expect(counters.active, baseline.active);
    expect(counters.completed, baseline.completed + 1);

    final nativeConsumed = await client.getObjectNativeStream(object);
    expect(
      await nativeConsumed.body.openRead().expand((chunk) => chunk).toList(),
      <int>[1, 2, 3],
    );
    counters = DartEdgeS3Client.downloadStreamCounters;
    expect(counters.active, baseline.active);
    expect(counters.completed, baseline.completed + 2);

    await client.getObjectStream(object);
    expect(DartEdgeS3Client.downloadStreamCounters.active, baseline.active + 1);
    client.dispose();
    counters = DartEdgeS3Client.downloadStreamCounters;
    expect(counters.active, baseline.active);
    expect(counters.canceled, baseline.canceled + 2);
  });

  test('forwards byte ranges and preserves partial object metadata', () async {
    final ranges = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      ranges.add(request.headers.value(HttpHeaders.rangeHeader));
      request.response
        ..statusCode = HttpStatus.partialContent
        ..contentLength = 3
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 2-4/10')
        ..headers.contentType = ContentType('audio', 'wav')
        ..add(const <int>[2, 3, 4]);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final client = await DartEdgeS3Client.open(
      S3ClientConfig(
        region: 'us-east-1',
        endpoint: 'http://127.0.0.1:${server.port}',
        accessKeyId: 'test',
        secretAccessKey: 'test',
        forcePathStyle: true,
        allowHttp: true,
      ),
    );
    addTearDown(client.dispose);

    final result = await client.getObjectNativeStream(
      const S3ObjectRef(bucket: 'recordings', key: 'sample.wav'),
      range: const HttpByteRange.closed(2, 4),
    );
    expect(await result.body.openRead().expand((chunk) => chunk).toList(), [
      2,
      3,
      4,
    ]);
    expect(ranges, ['bytes=2-4']);
    expect(result.metadata.contentLength, 3);
    expect(result.metadata.objectLength, 10);
    expect(result.metadata.contentRange, 'bytes 2-4/10');
  });

  test(
    'Dart and direct native HTTP streams return identical long objects',
    () async {
      final bytes = Uint8List(18 * 1024 * 1024);
      for (var index = 0; index < bytes.length; index += 1) {
        bytes[index] = index % 251;
      }

      final objectServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      objectServer.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..contentLength = bytes.length
          ..headers.contentType = ContentType('audio', 'wav')
          ..add(bytes);
        await request.response.close();
      });
      addTearDown(() => objectServer.close(force: true));

      final s3 = await DartEdgeS3Client.open(
        S3ClientConfig(
          region: 'us-east-1',
          endpoint: 'http://127.0.0.1:${objectServer.port}',
          accessKeyId: 'test',
          secretAccessKey: 'test',
          forcePathStyle: true,
          allowHttp: true,
        ),
      );
      addTearDown(s3.dispose);
      const object = S3ObjectRef(
        bucket: 'recordings',
        key: 'long-recording.wav',
      );
      const disposition = HttpHeader(
        'Content-Disposition',
        'attachment; filename="long-recording.wav"',
      );
      final baseline = DartEdgeS3Client.downloadStreamCounters;

      final app = DartEdge<void>(services: () {});
      app.get(
        '/dart',
        options: const RouteOptions(
          operationId: 'dartS3Stream',
          success: ResponseSpec.binary(contentType: 'audio/wav'),
        ),
        handler: (_) async {
          final result = await s3.getObjectStream(object);
          return BinaryStreamResponse(
            body: result.body,
            contentType: 'audio/wav',
            contentLength: result.metadata.contentLength,
            headers: const [disposition],
            onDispose: result.close,
          );
        },
      );
      app.get(
        '/native',
        options: const RouteOptions(
          operationId: 'nativeS3Stream',
          success: ResponseSpec.binary(contentType: 'audio/wav'),
        ),
        handler: (_) async {
          final result = await s3.getObjectNativeStream(object);
          return NativeBinaryStreamResponse(
            body: result.body,
            contentType: 'audio/wav',
            contentLength: result.metadata.contentLength,
            headers: const [disposition],
          );
        },
      );

      final server = await app.listen(port: 0);
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await server.close();
      });

      Future<
        ({
          int bodyLength,
          int checksum,
          String? disposition,
          int length,
          int status,
        })
      >
      download(String path) async {
        final response = await (await client.getUrl(
          Uri.http('127.0.0.1:${server.port}', path),
        )).close();
        var bodyLength = 0;
        var checksum = _checksumSeed;
        await for (final chunk in response) {
          bodyLength += chunk.length;
          checksum = _updateChecksum(checksum, chunk);
        }
        return (
          bodyLength: bodyLength,
          checksum: checksum,
          disposition: response.headers.value('content-disposition'),
          length: response.contentLength,
          status: response.statusCode,
        );
      }

      final dartResponse = await download('/dart');
      final nativeResponse = await download('/native');

      expect(nativeResponse.status, dartResponse.status);
      expect(nativeResponse.length, dartResponse.length);
      expect(nativeResponse.disposition, dartResponse.disposition);
      expect(nativeResponse.bodyLength, dartResponse.bodyLength);
      expect(nativeResponse.checksum, dartResponse.checksum);
      expect(nativeResponse.bodyLength, bytes.length);
      expect(nativeResponse.checksum, _updateChecksum(_checksumSeed, bytes));

      final counters = DartEdgeS3Client.downloadStreamCounters;
      expect(counters.active, baseline.active);
      expect(counters.started, baseline.started + 2);
      expect(counters.completed, baseline.completed + 2);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('serializes config and object references', () {
    const config = S3ClientConfig(
      region: 'us-east-1',
      endpoint: 'http://127.0.0.1:9000',
      accessKeyId: 'key',
      secretAccessKey: 'secret',
      forcePathStyle: true,
      allowHttp: true,
    );
    const object = S3ObjectRef(
      bucket: 'uploads',
      key: 'hello.txt',
      versionId: 'v1',
    );

    expect(config.toJson()['region'], 'us-east-1');
    expect(config.toJson()['forcePathStyle'], isTrue);
    expect(object.toJson()['bucket'], 'uploads');
    expect(object.toJson()['versionId'], 'v1');
  });

  test('defaults S3-compatible endpoint config without region', () {
    const config = S3ClientConfig(
      endpoint: 'http://127.0.0.1:9000',
      accessKeyId: 'key',
      secretAccessKey: 'secret',
      forcePathStyle: true,
      allowHttp: true,
    );

    expect(config.resolvedRegion, 'us-east-1');
    expect(config.resolveDefaults().region, 'us-east-1');
    expect(config.toJson()['region'], 'us-east-1');
    expect(config.toJson()['endpoint'], 'http://127.0.0.1:9000');
  });

  test('does not default region without endpoint', () {
    const config = S3ClientConfig(
      accessKeyId: 'key',
      secretAccessKey: 'secret',
    );

    expect(config.resolvedRegion, isNull);
    expect(config.toJson(), isNot(contains('region')));
  });
}

const _checksumSeed = 0xcbf29ce484222325;

int _updateChecksum(int checksum, Iterable<int> bytes) {
  var value = checksum;
  for (final byte in bytes) {
    value = ((value ^ byte) * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return value;
}
