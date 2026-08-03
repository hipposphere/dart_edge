import 'dart:io';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:dart_edge_sql_pgrust/dart_edge_sql_pgrust.dart';
import 'package:test/test.dart';

void main() {
  final executable = Platform.environment['PGRUST_TEST_EXECUTABLE'];
  final initdbExecutable =
      Platform.environment['PGRUST_TEST_INITDB_EXECUTABLE'];

  test(
    'executes SQL against a real pgrust server',
    () async {
      final database = await PgrustDatabase.temporary(
        executable: executable,
        initdbExecutable: initdbExecutable,
        postgresShareDirectory: Platform.environment['PGRUST_TEST_PGSHAREDIR'],
        timezoneDirectory: Platform.environment['PGRUST_TEST_TZDIR'],
      );
      final pool = database.asPostgresPool();

      try {
        final result = await pool.execute(
          sql("SELECT 'pg' || 'rust' AS database"),
        );
        expect(result.single.read<String>('database'), 'pgrust');
      } finally {
        await pool.close();
      }
    },
    skip: executable == null || initdbExecutable == null
        ? 'Set PGRUST_TEST_EXECUTABLE and PGRUST_TEST_INITDB_EXECUTABLE to '
              'run the real pgrust integration test.'
        : false,
  );
}
