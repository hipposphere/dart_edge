import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:dart_edge_sql_migrator/dart_edge_sql_migrator.dart';
import 'package:simple_test/src/database.dart';

Future<void> main() async {
  final database = buildDatabase();

  final migrator = await DartEdgeSqlMigrator.fromFolder(
    pool: database,
    folder: 'migrations',
  );
  await migrator.migrateToLatest();

  final schema = await PostgresIntrospector.fromDatabase(database).introspect();
  final emission = emitDartSchema(schema, databaseClassName: 'AppSchema');
  emission.writeToDirectory('lib/generated');
  await database.close();
  print('Database schema generated successfully.');
}
