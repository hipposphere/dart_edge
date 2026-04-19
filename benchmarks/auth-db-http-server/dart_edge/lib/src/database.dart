import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'benchmark_config.dart';

Future<SqliteDatabase> openDatabase() async {
  final directory = Directory('var').absolute;
  await directory.create(recursive: true);

  final file = File('${directory.path}/benchmark.sqlite');
  if (await file.exists()) {
    await file.delete();
  }
  await file.create();

  final database = SqliteDatabase.open(file.path);
  await database.execute(
    sql('''
    CREATE TABLE benchmark_values (
      email TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    '''),
  );
  await database.execute(
    SqlStatement.positional(
      'INSERT INTO benchmark_values (email, value) VALUES (?, ?)',
      [benchmarkUserEmail, benchmarkDatabaseValue],
    ),
  );

  for (var index = 0; index < benchmarkFlowUserCount; index += 1) {
    await database.execute(
      SqlStatement.positional(
        'INSERT INTO benchmark_values (email, value) VALUES (?, ?)',
        [benchmarkFlowUserEmail(index), benchmarkDatabaseValue],
      ),
    );
  }

  return database;
}
