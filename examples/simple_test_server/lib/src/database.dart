import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';

PostgresPool buildDatabase() {
  final file = File('db.pglite');
  if (file.existsSync()) {
    file.deleteSync();
  }
  final database = PostgresPool.pglite(PgliteDatabase.open(file.path));
  return database;
}
