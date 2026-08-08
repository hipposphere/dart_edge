import 'dart:io';

import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';
import 'package:dart_edge_s3_client/src/native/dart_edge_s3_client_native.dart';
import 'package:test/test.dart';

void main() {
  test('loads the native bundled asset', () {
    expect(DartEdgeS3ClientNative.abiVersion, greaterThanOrEqualTo(4));
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

    await client.getObjectStream(object);
    expect(DartEdgeS3Client.downloadStreamCounters.active, baseline.active + 1);
    client.dispose();
    counters = DartEdgeS3Client.downloadStreamCounters;
    expect(counters.active, baseline.active);
    expect(counters.canceled, baseline.canceled + 2);
  });

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
