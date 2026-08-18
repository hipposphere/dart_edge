import 'dart:async';
import 'dart:convert';

import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:test/test.dart';

void main() {
  test('parses PostgreSQL constructs across byte chunk boundaries', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);
    final statements = <SqlScriptStatement>[];
    final bytes = utf8.encode(r'''
      -- leading ; comment
      SELECT 'semi;colon', E'escaped\'quote;';
      SELECT "quoted;identifier";
      /* outer ; /* nested ; */ comment */
      DO $body$ BEGIN RAISE NOTICE 'hello;'; END $body$;
      SELECT 'Grüße';
    ''');

    final operation = pool.executeScript(
      Stream<List<int>>.fromIterable([
        for (final byte in bytes) <int>[byte],
      ]),
      dialect: SqlDialect.sqlite,
      totalBytes: bytes.length,
      onStatement: (statement) {
        statements.add(statement);
        return SqlScriptStatementAction.skip;
      },
    );
    final result = await operation.result;

    expect(result.bytesRead, bytes.length);
    expect(result.statementsCompleted, 4);
    expect(statements, hasLength(4));
    expect(statements[0].sql, contains("'semi;colon'"));
    expect(statements[1].sql, contains('"quoted;identifier"'));
    expect(statements[2].sql, contains("RAISE NOTICE 'hello;'"));
    expect(statements[3].sql, contains('Grüße'));
    expect(statements[0].byteOffset, 0);
  });

  test('preserve mode keeps explicit transactions on one session', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);
    final script = utf8.encode('''
      CREATE TABLE values_table (value INTEGER NOT NULL);
      BEGIN;
      INSERT INTO values_table (value) VALUES (1);
      ROLLBACK;
    ''');

    final result = await pool
        .executeScript(Stream.value(script), totalBytes: script.length)
        .result;

    expect(result.statementsCompleted, 4);
    expect(await pool.raw.from('values_table').selectAll().execute(), isEmpty);
  });

  test('atomic mode rolls back the complete script on failure', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);
    final script = utf8.encode('''
      CREATE TABLE rolled_back (value INTEGER NOT NULL);
      INSERT INTO missing_table (value) VALUES (1);
    ''');

    await expectLater(
      pool
          .executeScript(
            Stream.value(script),
            transactionMode: SqlScriptTransactionMode.atomic,
          )
          .result,
      throwsA(
        isA<SqlScriptException>()
            .having((error) => error.statementNumber, 'statementNumber', 2)
            .having(
              (error) => error.statementPreview,
              'preview',
              contains('missing_table'),
            ),
      ),
    );
    final tables = await pool.execute(
      sql(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rolled_back'",
      ),
    );
    expect(tables, isEmpty);
  });

  test('none mode rejects explicit transaction control', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    await expectLater(
      pool
          .executeScript(
            Stream.value(utf8.encode('BEGIN; SELECT 1;')),
            transactionMode: SqlScriptTransactionMode.none,
          )
          .result,
      throwsA(
        isA<SqlScriptException>().having(
          (error) => error.message,
          'message',
          contains('transaction control'),
        ),
      ),
    );
  });

  test('cancellation stops before reading the remaining source', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);
    var chunksRead = 0;
    late SqlScriptOperation operation;
    final source = (() async* {
      for (var index = 0; index < 20; index++) {
        chunksRead++;
        yield utf8.encode('SELECT $index;');
      }
    })();
    operation = pool.executeScript(
      source,
      onStatement: (statement) async {
        if (statement.number == 1) await operation.cancel();
        return SqlScriptStatementAction.skip;
      },
    );

    await expectLater(
      operation.result,
      throwsA(isA<SqlScriptCanceledException>()),
    );
    expect(chunksRead, lessThan(20));
  });

  test('reports parse errors with byte location and preview', () async {
    final pool = SqliteDatabase.inMemory();
    addTearDown(pool.close);

    await expectLater(
      pool
          .executeScript(
            Stream.value(utf8.encode("SELECT 1; SELECT 'unfinished")),
          )
          .result,
      throwsA(
        isA<SqlScriptException>()
            .having((error) => error.statementNumber, 'statementNumber', 2)
            .having((error) => error.byteOffset, 'byteOffset', 9)
            .having(
              (error) => error.statementPreview,
              'preview',
              contains('unfinished'),
            ),
      ),
    );
  });

  test(
    'parses a large dollar-quoted statement without quadratic copying',
    () async {
      final pool = SqliteDatabase.inMemory();
      addTearDown(pool.close);
      final body = ''.padRight(2 * 1024 * 1024, 'x');
      final bytes = utf8.encode(r'DO $large$' + body + r'$large$;');
      final stopwatch = Stopwatch()..start();

      final result = await pool
          .executeScript(
            _chunks(bytes, 64 * 1024),
            totalBytes: bytes.length,
            onStatement: (_) => SqlScriptStatementAction.skip,
          )
          .result;

      expect(result.statementsCompleted, 1);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    },
  );
}

Stream<List<int>> _chunks(List<int> bytes, int size) async* {
  for (var offset = 0; offset < bytes.length; offset += size) {
    final end = (offset + size).clamp(0, bytes.length);
    yield bytes.sublist(offset, end);
  }
}
