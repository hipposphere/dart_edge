import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';

const _mockS3VersionId = 'mock-version-1';

final class MockS3Server {
  MockS3Server._(this._server);

  final HttpServer _server;
  final Map<String, _StoredMockS3Object> _objects =
      <String, _StoredMockS3Object>{};

  static Future<MockS3Server> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final mockServer = MockS3Server._(server);
    server.listen((request) {
      unawaited(mockServer._handleRequest(request));
    });
    return mockServer;
  }

  Uri get endpoint => Uri.http('127.0.0.1:${_server.port}');

  Map<String, String> get environment => <String, String>{
    'BENCHMARK_S3_ENDPOINT': endpoint.toString(),
    'BENCHMARK_S3_BUCKET': benchmarkS3Bucket,
    'BENCHMARK_S3_REGION': benchmarkS3Region,
    'BENCHMARK_S3_ACCESS_KEY_ID': benchmarkS3AccessKeyId,
    'BENCHMARK_S3_SECRET_ACCESS_KEY': benchmarkS3SecretAccessKey,
  };

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final objectRef = _parseObjectRef(request.uri);
    if (objectRef == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = _xmlContentType
        ..write(_errorXml('InvalidURI', 'Expected /<bucket>/<key>.'));
      await request.response.close();
      return;
    }

    final key = '${objectRef.bucket}/${objectRef.key}';

    switch (request.method) {
      case 'PUT':
        final bytes = await _readBytes(request);
        final contentType =
            request.headers.contentType?.mimeType ??
            benchmarkMultipartFileContentType;
        final metadata = _readMetadata(request.headers);
        final eTag =
            '"mock-${objectRef.bucket}-${objectRef.key}-${bytes.length}"';

        _objects[key] = _StoredMockS3Object(
          bytes: bytes,
          contentType: contentType,
          metadata: metadata,
          eTag: eTag,
        );

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.set(HttpHeaders.etagHeader, eTag)
          ..headers.set('x-amz-version-id', _mockS3VersionId)
          ..headers.contentLength = 0;
        await request.response.close();
        return;
      case 'GET':
      case 'HEAD':
        final object = _objects[key];
        if (object == null) {
          request.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = _xmlContentType
            ..write(
              _errorXml('NoSuchKey', 'The specified key does not exist.'),
            );
          await request.response.close();
          return;
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.parse(object.contentType)
          ..headers.set(HttpHeaders.etagHeader, object.eTag)
          ..headers.set('x-amz-version-id', _mockS3VersionId)
          ..headers.contentLength = object.bytes.length;
        for (final entry in object.metadata.entries) {
          request.response.headers.set('x-amz-meta-${entry.key}', entry.value);
        }

        if (request.method == 'GET') {
          request.response.add(object.bytes);
        }
        await request.response.close();
        return;
      case 'DELETE':
        _objects.remove(key);
        request.response
          ..statusCode = HttpStatus.noContent
          ..headers.contentLength = 0;
        await request.response.close();
        return;
      default:
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..headers.contentLength = 0;
        await request.response.close();
        return;
    }
  }
}

final class _ParsedObjectRef {
  const _ParsedObjectRef({required this.bucket, required this.key});

  final String bucket;
  final String key;
}

final class _StoredMockS3Object {
  const _StoredMockS3Object({
    required this.bytes,
    required this.contentType,
    required this.metadata,
    required this.eTag,
  });

  final Uint8List bytes;
  final String contentType;
  final Map<String, String> metadata;
  final String eTag;
}

_ParsedObjectRef? _parseObjectRef(Uri uri) {
  if (uri.pathSegments.length < 2) {
    return null;
  }

  final bucket = uri.pathSegments.first;
  final key = uri.pathSegments.skip(1).join('/');
  if (bucket.isEmpty || key.isEmpty) {
    return null;
  }

  return _ParsedObjectRef(bucket: bucket, key: key);
}

Future<Uint8List> _readBytes(HttpRequest request) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Map<String, String> _readMetadata(HttpHeaders headers) {
  final metadata = <String, String>{};
  headers.forEach((name, values) {
    if (name.startsWith('x-amz-meta-')) {
      metadata[name.substring('x-amz-meta-'.length)] = values.join(',');
    }
  });
  return metadata;
}

String _errorXml(String code, String message) {
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<Error><Code>$code</Code><Message>$message</Message></Error>';
}

final _xmlContentType = ContentType('application', 'xml', charset: 'utf-8');
