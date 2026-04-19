import 'dart:typed_data';

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
        bytes: Uint8List.fromList('hello from dart_edge_s3_client'.codeUnits),
        contentType: 'text/plain; charset=utf-8',
      ),
    );

    final metadata = await client.headObject(
      const S3ObjectRef(bucket: 'uploads', key: 'hello.txt'),
    );
    print('Stored object content-type: ${metadata.contentType}');

    final download = await client.getObjectBytes(
      const S3ObjectRef(bucket: 'uploads', key: 'hello.txt'),
    );
    print('Downloaded ${download.bytes.length} bytes');
  } finally {
    client.dispose();
  }
}
