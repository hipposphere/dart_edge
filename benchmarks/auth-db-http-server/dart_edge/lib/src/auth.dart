import 'dart:io';

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
  await _signUp(
    auth.api.withForwardedFor(_seedForwardedFor(0)),
    email: benchmarkUserEmail,
    password: benchmarkUserPassword,
    name: benchmarkUserName,
  );

  for (var index = 0; index < benchmarkFlowUserCount; index += 1) {
    await _signUp(
      auth.api.withForwardedFor(_seedForwardedFor(index + 1)),
      email: benchmarkFlowUserEmail(index),
      password: benchmarkUserPassword,
      name: benchmarkFlowUserName(index),
    );
  }
}

Future<void> _signUp(
  DartEdgeAuthApi api, {
  required String email,
  required String password,
  required String name,
}) async {
  await api.signUpEmail(email: email, password: password, name: name);
  return;
}

String _seedForwardedFor(int userIndex) {
  final thirdOctet = (userIndex ~/ 254) % 255;
  final fourthOctet = (userIndex % 254) + 1;
  return '203.0.$thirdOctet.$fourthOctet';
}
