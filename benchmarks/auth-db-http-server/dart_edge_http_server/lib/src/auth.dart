import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'benchmark_config.dart';

DartEdgeAuth createAuth({required int port, required SqliteDatabase database}) {
  return DartEdgeAuth(
    DartEdgeAuthConfig(
      workerPoolSize: 1,
      secret: benchmarkAuthSecret,
      baseUrl: benchmarkOriginForPort(port),
      basePath: '/auth',
      enableRateLimit: false,
      database: DartEdgeAuthDatabase.fromDatabase(database),
    ),
  );
}

Future<void> seedUsers(DartEdgeAuth auth) async {
  for (var index = 0; index < benchmarkUserCount; index += 1) {
    await auth.api.signUpEmail(
      email: benchmarkUserEmail(index),
      password: benchmarkUserPassword,
      name: benchmarkUserName(index),
    );
  }
}
