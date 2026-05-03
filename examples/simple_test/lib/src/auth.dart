import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

DartEdgeAuth buildAuth(SqlPool database) {
  return DartEdgeAuth(
    DartEdgeAuthConfig(
      secret:
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      baseUrl: 'http://localhost:3100',
      database: DartEdgeAuthDatabase.fromDatabase(database),
      admin: const DartEdgeAuthAdminConfig(),
    ),
  );
}
