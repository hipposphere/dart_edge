import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';

Future<void> main() async {
  final pool = SqliteDatabase.inMemory();
  final migrator = DartEdgeSqlMigrator(
    pool: pool,
    migrations: [
      SqlMigration(
        version: '0001',
        name: 'create_users',
        up: SqlMigrationPlan.sql([
          '''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL
          )
          ''',
        ]),
        down: SqlMigrationPlan.sql(['DROP TABLE users']),
      ),
      SqlMigration(
        version: '0002',
        name: 'create_user_profiles',
        up: SqlMigrationPlan.sql([
          '''
          CREATE TABLE user_profiles (
            user_id INTEGER PRIMARY KEY,
            display_name TEXT NOT NULL
          )
          ''',
        ]),
        down: SqlMigrationPlan.sql(['DROP TABLE user_profiles']),
      ),
    ],
  );

  final applied = await migrator.migrateToLatest();
  print('Applied $applied migrations.');

  final status = await migrator.status();
  print('Database up to date: ${status.isUpToDate}');

  await pool.close();
}
