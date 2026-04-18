import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';

Future<void> main() async {
  final pool = SqliteDatabase.inMemory();
  final migrationsFolder = Directory(
    '${Directory.current.path}/example/migrations',
  ).path;

  final migrator = await DartEdgeSqlMigrator.fromFolder(
    pool: pool,
    folder: migrationsFolder,
    sorting: const SqlMigrationFileSorting.flyway(),
  );

  final applied = await migrator.migrateToLatest();
  print('Applied $applied migrations from $migrationsFolder.');

  final rows = await pool.execute(sql('SELECT email FROM users ORDER BY id'));
  final emails = rows.rows
      .map((SqlRow row) => row.read<String>('email'))
      .join(', ');
  print('Seeded users: $emails');

  await pool.close();
}
