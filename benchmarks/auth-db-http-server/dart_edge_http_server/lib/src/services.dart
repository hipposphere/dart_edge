import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_s3_client/dart_edge_s3_client.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

final class Services {
  const Services({
    required this.auth,
    required this.database,
    required this.s3Client,
    required this.s3Bucket,
  });

  final DartEdgeAuth auth;
  final SqliteDatabase database;
  final DartEdgeS3Client s3Client;
  final String s3Bucket;
}
