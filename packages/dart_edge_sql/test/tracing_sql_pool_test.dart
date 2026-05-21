import 'package:dart_edge_sql/dart_edge_sql.dart';
import 'package:test/test.dart';

void main() {
  test('traces executed statements with compiled SQL and results', () async {
    final delegate = SqliteDatabase.inMemory();
    final events = <SqlTraceEvent>[];
    final pool = TracingSqlPool(delegate, onTrace: events.add);
    addTearDown(pool.close);

    await pool.execute(
      sql('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)'),
    );
    await pool.execute(
      SqlStatement.named('INSERT INTO users (email) VALUES (:email)', {
        'email': 'ada@example.com',
      }),
    );
    final result = await pool.execute(
      SqlStatement.named('SELECT email FROM users WHERE email = :email', {
        'email': 'ada@example.com',
      }),
    );

    expect(result.single['email'], 'ada@example.com');
    expect(events, hasLength(3));

    final insert = events[1];
    expect(insert.source, SqlTraceSource.pool);
    expect(insert.operation, SqlTraceOperation.execute);
    expect(insert.statement.sql, contains(':email'));
    expect(
      insert.compiledStatement.sql,
      'INSERT INTO users (email) VALUES (?)',
    );
    expect(insert.compiledStatement.positionalParameters, ['ada@example.com']);
    expect(insert.succeeded, isTrue);
    expect(insert.duration, isA<Duration>());

    final select = events[2];
    expect(select.returnedRows, 1);
    expect(select.result?.single['email'], 'ada@example.com');
  });

  test('traces transaction and prepared statement executions', () async {
    final delegate = SqliteDatabase.inMemory();
    final events = <SqlTraceEvent>[];
    final pool = TracingSqlPool(delegate, onTrace: events.add);
    addTearDown(pool.close);

    await pool.execute(
      sql('CREATE TABLE counters (id INTEGER PRIMARY KEY, value INTEGER)'),
    );

    await pool.withTransaction((transaction) async {
      await transaction.execute(
        SqlStatement.named('INSERT INTO counters (id, value) VALUES (:id, 1)', {
          'id': 1,
        }),
      );

      final prepared = await transaction.prepare(
        SqlStatement.named(
          'UPDATE counters SET value = value + :amount WHERE id = :id',
          {'amount': 1, 'id': 1},
        ),
      );
      addTearDown(prepared.close);
      await prepared.execute(parameters: {'amount': 41, 'id': 1});
    });

    expect(events.map((event) => event.source), [
      SqlTraceSource.pool,
      SqlTraceSource.transaction,
      SqlTraceSource.transaction,
      SqlTraceSource.preparedStatement,
    ]);
    expect(events.map((event) => event.operation), [
      SqlTraceOperation.execute,
      SqlTraceOperation.execute,
      SqlTraceOperation.prepare,
      SqlTraceOperation.preparedExecute,
    ]);
    expect(events.last.compiledStatement.sql, contains('?'));
    expect(events.last.compiledStatement.positionalParameters, [41, 1]);

    final result = await pool.execute(sql('SELECT value FROM counters'));
    expect(result.single['value'], 42);
  });

  test('traces failed statements without hiding the original error', () async {
    final delegate = SqliteDatabase.inMemory();
    final events = <SqlTraceEvent>[];
    final pool = TracingSqlPool(delegate, onTrace: events.add);
    addTearDown(pool.close);

    await expectLater(
      pool.execute(sql('SELECT * FROM missing_table')),
      throwsA(isA<StateError>()),
    );

    expect(events, hasLength(1));
    expect(events.single.succeeded, isFalse);
    expect(events.single.error, isNotNull);
    expect(events.single.stackTrace, isNotNull);
    expect(events.single.compiledStatement.sql, 'SELECT * FROM missing_table');
  });

  test(
    'does not fail SQL execution when trace sink throws by default',
    () async {
      final delegate = SqliteDatabase.inMemory();
      final pool = TracingSqlPool(
        delegate,
        onTrace: (_) => throw StateError('trace failed'),
      );
      addTearDown(pool.close);

      final result = await pool.execute(sql('SELECT 1 AS value'));

      expect(result.single['value'], 1);
    },
  );

  test('preserves SQL errors when propagated trace sink throws', () async {
    final pool = TracingSqlPool(
      _FailingPool(),
      onTrace: (_) => throw StateError('trace failed'),
      propagateTraceErrors: true,
    );

    await expectLater(
      pool.execute(sql('SELECT 1')),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'sql failed',
        ),
      ),
    );
  });

  test('does not validate statement parameters before prepare', () async {
    final delegate = _PreparingPool();
    final events = <SqlTraceEvent>[];
    final pool = TracingSqlPool(delegate, onTrace: events.add);

    final prepared = await pool.withSession((session) {
      return session.prepare(
        SqlStatement.named('SELECT :missing AS value', const {}),
      );
    });

    expect(prepared.statement.sql, 'SELECT :missing AS value');
    expect(events, hasLength(1));
    expect(events.single.operation, SqlTraceOperation.prepare);
    expect(events.single.statement.sql, 'SELECT :missing AS value');
    expect(events.single.compiledStatement.sql, 'SELECT :missing AS value');
  });
}

final class _FailingPool implements SqlPool {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    throw const FormatException('sql failed');
  }

  @override
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action) {
    throw UnimplementedError();
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}
}

final class _PreparingPool implements SqlPool {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    throw UnimplementedError();
  }

  @override
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action) {
    return action(_PreparingSession());
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}
}

final class _PreparingSession implements SqlSession {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    throw UnimplementedError();
  }

  @override
  Future<PreparedSqlStatement> prepare(SqlStatement statement) async {
    return _PreparedStatement(statement);
  }
}

final class _PreparedStatement implements PreparedSqlStatement {
  const _PreparedStatement(this.statement);

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  final SqlStatement statement;

  @override
  Future<SqlResult> execute({Object? parameters}) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}
}
