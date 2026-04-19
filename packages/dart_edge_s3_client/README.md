# dart_edge_s3_client

Native-backed S3 client for Dart Edge.

This package wraps a bundled Rust S3 client and supports both metadata-only
operations and native byte transfer for uploads and downloads. It is intended
for server-side Dart applications that need to talk to AWS S3 or compatible
endpoints such as MinIO and Cloudflare R2.

## Quick Start

```dart
import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';

Future<void> main() async {
  final client = await DartEdgeS3Client.open(
    const S3ClientConfig(
      region: 'us-east-1',
      endpoint: 'http://127.0.0.1:9000',
      accessKeyId: 'minioadmin',
      secretAccessKey: 'minioadmin',
      forcePathStyle: true,
      allowHttp: true,
    ),
  );

  try {
    await client.putObjectBytes(
      S3PutObjectBytesRequest(
        bucket: 'uploads',
        key: 'hello.txt',
        bytes: Uint8List.fromList('hello'.codeUnits),
        contentType: 'text/plain; charset=utf-8',
      ),
    );

    final object = await client.getObjectBytes(
      const S3ObjectRef(bucket: 'uploads', key: 'hello.txt'),
    );
    print(object.metadata.contentType);
    print(object.bytes.length);
  } finally {
    client.dispose();
  }
}
```

## Main Types

- `DartEdgeS3Client` owns one native client handle
- `S3ClientConfig` configures the region, credentials, and optional custom
  endpoint
- `S3PutObjectBytesRequest` uploads in-memory bytes through the native bytes
  path
- `S3ObjectRef` identifies one object for `get`, `head`, and `delete`
- `S3ObjectMetadata` describes object metadata returned by `head` and `get`

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_s3_client.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_s3_client run ffigen --config tool/ffigen.yaml
```
