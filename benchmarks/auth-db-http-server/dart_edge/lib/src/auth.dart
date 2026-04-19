import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

DartEdgeAuth createAuth({required int port, required SqliteDatabase database}) {
  return DartEdgeAuth(
    DartEdgeAuthConfig(
      secret: benchmarkAuthSecret,
      baseUrl: benchmarkOriginForPort(port),
      basePath: benchmarkAuthPath,
      database: DartEdgeAuthDatabase.fromDatabase(database),
    ),
  );
}

Future<void> seedUsers(DartEdgeAuth auth) async {
  await auth.api.signUpEmail(
    email: benchmarkUserEmail,
    password: benchmarkUserPassword,
    name: benchmarkUserName,
  );
}
