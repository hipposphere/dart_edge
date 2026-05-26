import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

DartEdgeAuth buildAuth(
  SqlPool database, {
  String baseUrl = 'http://localhost:3100',
}) {
  return DartEdgeAuth(
    DartEdgeAuthConfig(
      workerPoolSize: 1,
      secret:
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      baseUrl: baseUrl,
      database: DartEdgeAuthDatabase.fromDatabase(database),
      admin: const DartEdgeAuthAdminConfig(),
    ),
  );
}
