import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';

SqliteDatabase buildDatabase() {
  if (File('simple_test_new.db').existsSync() == false) {
    File('simple_test_new.db').createSync();
  }
  final database = SqliteDatabase.open('simple_test_new.db');
  return database;
}
