import 'dart:isolate';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pglite/dart_edge_sql_pglite.dart';

Future<void> main(List<String> args, Object? message) async {
  final readyPort = message! as SendPort;
  final pool = PgliteDatabase.open(args.single).asPostgresPool();
  await pool.execute(
    sql('CREATE TABLE isolate_restart_test (value TEXT NOT NULL)'),
  );
  await pool.execute(
    sql("INSERT INTO isolate_restart_test (value) VALUES ('persisted')"),
  );

  await pool.withTransaction((transaction) async {
    await transaction.execute(
      sql("UPDATE isolate_restart_test SET value = 'orphaned'"),
    );
    readyPort.send('ready');
    Isolate.exit();
  });
}
