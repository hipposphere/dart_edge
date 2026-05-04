import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';
import 'package:dart_edge_s3_client/src/native/dart_edge_s3_client_native.dart';
import 'package:test/test.dart';

void main() {
  test('loads the native bundled asset', () {
    expect(DartEdgeS3ClientNative.abiVersion, greaterThanOrEqualTo(2));
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

  test('serializes S3-compatible endpoint config without region', () {
    const config = S3ClientConfig(
      endpoint: 'http://127.0.0.1:9000',
      accessKeyId: 'key',
      secretAccessKey: 'secret',
      forcePathStyle: true,
      allowHttp: true,
    );

    expect(config.toJson(), isNot(contains('region')));
    expect(config.toJson()['endpoint'], 'http://127.0.0.1:9000');
  });
}
