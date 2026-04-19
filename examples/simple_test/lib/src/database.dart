import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';

SqliteDatabase buildDatabase() {
  final file = File('sqlite.db');
  if (file.existsSync()) {
    file.deleteSync();
  }
  file.createSync();
  final database = SqliteDatabase.open(file.path);
  return database;
}
