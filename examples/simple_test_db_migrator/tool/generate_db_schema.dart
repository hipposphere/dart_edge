import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_codegen/dart_edge_sql_codegen.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';
import 'package:simple_test_db_migrator/simple_test_db_migrator.dart';

Future<void> main() async {
  final database = buildDatabase();

  await migrateSimpleTestDatabase(database, folder: 'migrations');

  final schema = await PostgresIntrospector.fromDatabase(database).introspect();
  final emission = emitDartSchema(schema, databaseClassName: 'AppSchema');
  final output = Directory('../simple_test_db_models/lib/generated');
  emission.writeToDirectory(output.path);
  await _preferCoreImports(output);
  await database.close();
  print('Database schema generated successfully.');
}

PostgresPool buildDatabase() {
  final file = File('db.pglite');
  if (file.existsSync()) {
    file.deleteSync();
  }
  return PostgresPool.pglite(PgliteDatabase.open(file.path));
}

Future<void> _preferCoreImports(Directory output) async {
  await for (final entity in output.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final source = await entity.readAsString();
    await entity.writeAsString(
      source.replaceAll(
        'package:dart_edge_http_server_runtime/dart_edge_http_server_runtime.dart',
        'package:dart_edge_core/dart_edge_core.dart',
      ),
    );
  }
}
