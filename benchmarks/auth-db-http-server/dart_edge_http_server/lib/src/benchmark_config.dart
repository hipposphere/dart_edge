import 'dart:io';

import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';
import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';

/// Shared Better Auth secret used by benchmark targets.
const benchmarkAuthSecret = 'benchmark-secret-key-that-is-at-least-32-chars';

/// Number of benchmark users seeded into the Dart Edge target.
const benchmarkUserCount = 256;

const benchmarkUserPassword = 'password123456';

/// Stable benchmark payload stored in the benchmark database.
const benchmarkDatabaseValue = 'database benchmark value';

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

String get benchmarkS3Endpoint =>
    Platform.environment['BENCHMARK_S3_ENDPOINT'] ?? 'http://127.0.0.1:9321';

String get benchmarkS3BucketName =>
    Platform.environment['BENCHMARK_S3_BUCKET'] ?? benchmarkS3Bucket;

String get benchmarkS3RegionName =>
    Platform.environment['BENCHMARK_S3_REGION'] ?? benchmarkS3Region;

String get benchmarkS3AccessKey =>
    Platform.environment['BENCHMARK_S3_ACCESS_KEY_ID'] ??
    benchmarkS3AccessKeyId;

String get benchmarkS3Secret =>
    Platform.environment['BENCHMARK_S3_SECRET_ACCESS_KEY'] ??
    benchmarkS3SecretAccessKey;

Future<DartEdgeS3Client> openBenchmarkS3Client() {
  return DartEdgeS3Client.open(
    S3ClientConfig(
      region: benchmarkS3RegionName,
      endpoint: benchmarkS3Endpoint,
      accessKeyId: benchmarkS3AccessKey,
      secretAccessKey: benchmarkS3Secret,
      forcePathStyle: true,
      allowHttp: true,
    ),
  );
}
