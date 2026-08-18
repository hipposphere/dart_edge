# dart_edge_s3_client

Native-backed S3 client for Dart Edge.

This package wraps a bundled Rust S3 client and supports both metadata-only
operations and native byte transfer for uploads and downloads. It is intended
for server-side Dart applications that need to talk to AWS S3 or compatible
endpoints such as RustFS, MinIO, and Cloudflare R2.

## Quick Start

```dart
import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';

Future<void> main() async {
  final client = await DartEdgeS3Client.open(
    const S3ClientConfig(
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
- `S3ClientConfig` configures optional region, credentials, and custom endpoint
- `S3PutObjectBytesRequest` uploads in-memory bytes through the native bytes
  path
- `S3ObjectRef` identifies one object for `get`, `head`, and `delete`
- `S3ObjectMetadata` describes object metadata returned by `head` and `get`

## Native streaming bodies

`putObjectNativeStream` adopts a compatible single-owner native body and feeds
it directly into the S3 request. The producer's chunk allocation remains alive
until the AWS HTTP stack has consumed it; the payload is not copied into Dart:

```dart
await client.putObjectNativeStream(
  bucket: 'recordings',
  key: 'segment-id',
  body: encodedAudio.body,
  contentLength: encodedAudio.contentLength,
  contentType: encodedAudio.mimeType,
);
```

The declared content length must exactly match the producer output. Native
stream uploads are single-use and non-replayable, so callers should create a
fresh stream if an application-level retry is required.

`getObjectNativeStream` returns a single-owner native body. Application code
may either read copied Dart chunks with `body.openRead()` or transfer the body
directly to the Dart Edge HTTP runtime:

```dart
final object = await client.getObjectNativeStream(
  const S3ObjectRef(bucket: 'recordings', key: 'recording.wav'),
);

return NativeBinaryStreamResponse(
  body: object.body,
  contentType: object.metadata.contentType ?? 'application/octet-stream',
  contentLength: object.metadata.contentLength,
);
```

All GET APIs accept a single closed, open-ended, or suffix byte range. Native
streams keep the selected bytes outside the Dart heap and expose both the
selected `contentLength` and total `objectLength`:

```dart
final object = await client.getObjectNativeStream(
  const S3ObjectRef(bucket: 'recordings', key: 'long.wav'),
  range: const HttpByteRange.closed(0, 1024 * 1024 - 1),
);
```

The two consumption modes are mutually exclusive. Call `object.close()` when
neither mode adopts the body. When transferred to the native HTTP runtime, the
original AWS-owned chunk allocation stays alive until Hyper finishes sending
it; only its pointer and length cross the native ABI.

## Runtime workers

The native S3 client uses a shared Tokio runtime with at most four worker
threads by default, further limited by the process's available parallelism.
Set `DART_EDGE_S3_WORKER_THREADS` before the first client is opened to choose a
different worker count. Values above 32 are capped at 32. The general Tokio
`TOKIO_WORKER_THREADS` setting is used as a fallback when the package-specific
setting is absent.

For a separate-process comparison of the Dart and native HTTP paths, run:

```sh
dart run tool/s3_http_stream_benchmark.dart dart
dart run tool/s3_http_stream_benchmark.dart native
```

## Native Bindings

The low-level Dart FFI layer is generated with `package:ffigen`, not written by
hand.

- ABI header: `rust/include/dart_edge_s3_client.h`
- Generated Dart bindings: `lib/src/native/generated_bindings.dart`
- Regenerate after ABI changes:

```sh
dart pub -C packages/dart_edge_s3_client run ffigen --config tool/ffigen.yaml
```
