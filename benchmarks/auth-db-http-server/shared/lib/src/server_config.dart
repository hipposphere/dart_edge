import 'dart:convert';
import 'dart:typed_data';

/// Plain-text response returned by the health probe route.
const benchmarkHealthBody = 'ok';

/// Shared Better Auth secret used by both benchmark targets.
const benchmarkAuthSecret = 'benchmark-secret-key-that-is-at-least-32-chars';

/// Number of benchmark users seeded into both targets.
const benchmarkUserCount = 256;

const benchmarkUserPassword = 'password123456';

/// Stable benchmark route layout.
const benchmarkAuthPath = '/auth';
const benchmarkHealthPath = '/healthz';
const benchmarkRawPath = '/bench/raw';
const benchmarkDatabasePath = '/bench/db';
const benchmarkUploadMultipartPath = '/upload_multipart';

/// Stable benchmark payloads.
const benchmarkRawValue = 'raw benchmark value';
const benchmarkDatabaseValue = 'database benchmark value';
const benchmarkS3Region = 'us-east-1';
const benchmarkS3Bucket = 'benchmark-uploads';
const benchmarkS3AccessKeyId = 'benchmark-access-key';
const benchmarkS3SecretAccessKey = 'benchmark-secret-access-key';
const benchmarkMultipartTitleFieldName = 'title';
const benchmarkMultipartTitleValue = 'benchmark upload';
const benchmarkMultipartFileFieldName = 'upload';
const benchmarkMultipartFileName = 'payload.bin';
const benchmarkMultipartFileContentType = 'application/octet-stream';

final Uint8List benchmarkMultipartFileBytes = Uint8List.fromList(
  utf8.encode(
    List.filled(1024, 'dart-edge-auth-db-benchmark-upload-0123456789\n').join(),
  ),
);

/// Parses `--port=` from CLI [args].
int parseBenchmarkPort(List<String> args, {int defaultPort = 8080}) {
  for (final argument in args) {
    if (argument.startsWith('--port=')) {
      return int.parse(argument.substring('--port='.length));
    }
  }

  return defaultPort;
}

/// Builds the canonical origin value used by auth requests.
String benchmarkOriginForPort(int port) => 'http://127.0.0.1:$port';

/// Builds the canonical benchmark user name for [index].
String benchmarkUserName(int index) => 'Benchmark User $index';

/// Builds the canonical benchmark user email for [index].
String benchmarkUserEmail(int index) => 'benchmark.user-$index@example.com';

/// Builds the canonical sign-in request body for benchmark user [index].
String benchmarkSignInRequestJson([int index = 0]) {
  return jsonEncode({
    'email': benchmarkUserEmail(index),
    'password': benchmarkUserPassword,
  });
}

/// Builds the canonical authed raw response body.
String benchmarkRawResponseJson(String email) {
  return jsonEncode({'email': email, 'value': benchmarkRawValue});
}

/// Builds the canonical authed database response body.
String benchmarkDatabaseResponseJson(String email) {
  return jsonEncode({'email': email, 'value': benchmarkDatabaseValue});
}

/// Builds the canonical benchmark upload key for [email].
String benchmarkUploadObjectKey(String email) {
  return '$email/$benchmarkMultipartFileName';
}

/// Builds the canonical upload-multipart response body.
String benchmarkUploadMultipartResponseJson(String email) {
  return jsonEncode({
    'email': email,
    'bucket': benchmarkS3Bucket,
    'key': benchmarkUploadObjectKey(email),
    'title': benchmarkMultipartTitleValue,
    'fileName': benchmarkMultipartFileName,
    'contentType': benchmarkMultipartFileContentType,
    'size': benchmarkMultipartFileBytes.length,
  });
}

/// Builds one deterministic multipart/form-data request body for the benchmark.
Uint8List buildBenchmarkMultipartRequestBody(String boundary) {
  final builder = BytesBuilder(copy: false);

  void addAscii(String value) {
    builder.add(ascii.encode(value));
  }

  addAscii(
    '--$boundary\r\n'
    'Content-Disposition: form-data; name="$benchmarkMultipartTitleFieldName"\r\n'
    '\r\n'
    '$benchmarkMultipartTitleValue\r\n'
    '--$boundary\r\n'
    'Content-Disposition: form-data; '
    'name="$benchmarkMultipartFileFieldName"; '
    'filename="$benchmarkMultipartFileName"\r\n'
    'Content-Type: $benchmarkMultipartFileContentType\r\n'
    '\r\n',
  );
  builder.add(benchmarkMultipartFileBytes);
  addAscii('\r\n--$boundary--\r\n');

  return builder.takeBytes();
}

/// Builds the multipart content-type header for [boundary].
String benchmarkMultipartContentType(String boundary) {
  return 'multipart/form-data; boundary=$boundary';
}
