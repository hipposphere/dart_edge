import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';

const simpleTestMigrationsFolder = '../simple_test_db_migrator/migrations';

Future<void> migrateSimpleTestDatabase(
  PostgresPool database, {
  String folder = simpleTestMigrationsFolder,
}) async {
  final migrator = await DartEdgeSqlMigrator.fromFolder(
    pool: database,
    folder: folder,
  );
  await migrator.migrateToLatest();
}
