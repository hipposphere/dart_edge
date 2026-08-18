import 'dart:ffi';

import '../../core/sql_dialect.dart';
import '../../core/sql_executor.dart';
import '../../core/sql_result.dart';
import '../../core/sql_statement.dart';
import '../../native/dart_edge_sql_native.dart';
import 'compiled_sql_statement.dart';

final class NativeSqlPoolDelegate implements SqlPool, Finalizable {
  NativeSqlPoolDelegate._({required this.dialect, required this._handle}) {
    DartEdgeSqlNative.attachPoolFinalizer(this, _handle);
  }

  factory NativeSqlPoolDelegate.openPostgres(
    String connectionString, {
    required int maxSessions,
  }) {
    return NativeSqlPoolDelegate._(
      dialect: SqlDialect.postgres,
      handle: DartEdgeSqlNative.openPostgresPool(
        connectionString,
        maxSessions: maxSessions,
      ),
    );
  }

  factory NativeSqlPoolDelegate.openSqlite(
    String path, {
    required int maxSessions,
  }) {
    return NativeSqlPoolDelegate._(
      dialect: SqlDialect.sqlite,
      handle: DartEdgeSqlNative.openSqlitePool(path, maxSessions: maxSessions),
    );
  }

  factory NativeSqlPoolDelegate.openSqliteInMemory({required int maxSessions}) {
    return NativeSqlPoolDelegate._(
      dialect: SqlDialect.sqlite,
      handle: DartEdgeSqlNative.openSqliteInMemoryPool(
        maxSessions: maxSessions,
      ),
    );
  }

  @override
  final SqlDialect dialect;
  final int _handle;
  var _closed = false;

  int get nativeHandle => _handle;

  @override
  Future<SqlResult> execute(SqlStatement statement) async {
    _ensureOpen();
    return DartEdgeSqlNative.executePool(
      _handle,
      compileSqlStatement(dialect, statement),
    );
  }

  @override
  Future<T> withSession<T>(
    Future<T> Function(SqlSession session) action,
  ) async {
    _ensureOpen();
    return action(
      NativeSqlSession(
        dialect: dialect,
        executeStatement: (statement) {
          return execute(statement);
        },
      ),
    );
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) async {
    _ensureOpen();
    final transactionHandle = DartEdgeSqlNative.beginTransaction(_handle);
    final transaction = NativeSqlTransaction(
      dialect: dialect,
      handle: transactionHandle,
    );

    try {
      final result = await action(transaction);
      transaction.commit();
      return result;
    } catch (_) {
      transaction.rollback();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    DartEdgeSqlNative.closePool(_handle);
    DartEdgeSqlNative.detachPoolFinalizer(this);
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('SQL pool has already been closed.');
    }
  }
}

final class NativeSqlSession implements SqlSession {
  const NativeSqlSession({
    required this.dialect,
    required this.executeStatement,
  });

  @override
  final SqlDialect dialect;
  final Future<SqlResult> Function(SqlStatement statement) executeStatement;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    return executeStatement(statement);
  }

  @override
  Future<PreparedSqlStatement> prepare(SqlStatement statement) async {
    return NativePreparedSqlStatement(
      dialect: dialect,
      statement: statement,
      executeStatement: executeStatement,
    );
  }
}

final class NativeSqlTransaction implements SqlTransaction, Finalizable {
  NativeSqlTransaction({required this.dialect, required this._handle}) {
    DartEdgeSqlNative.attachTransactionFinalizer(this, _handle);
  }

  @override
  final SqlDialect dialect;

  final int _handle;
  var _closed = false;

  @override
  Future<SqlResult> execute(SqlStatement statement) async {
    _ensureOpen();
    return DartEdgeSqlNative.executeTransaction(
      _handle,
      compileSqlStatement(dialect, statement),
    );
  }

  @override
  Future<PreparedSqlStatement> prepare(SqlStatement statement) async {
    _ensureOpen();
    return NativePreparedSqlStatement(
      dialect: dialect,
      statement: statement,
      executeStatement: execute,
    );
  }

  void commit() {
    if (_closed) {
      return;
    }
    _closed = true;
    try {
      DartEdgeSqlNative.commitTransaction(_handle);
    } finally {
      DartEdgeSqlNative.detachTransactionFinalizer(this);
    }
  }

  void rollback() {
    if (_closed) {
      return;
    }
    _closed = true;
    DartEdgeSqlNative.rollbackTransaction(_handle);
    DartEdgeSqlNative.detachTransactionFinalizer(this);
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('SQL transaction has already been completed.');
    }
  }
}

final class NativePreparedSqlStatement implements PreparedSqlStatement {
  const NativePreparedSqlStatement({
    required this.dialect,
    required this.statement,
    required this.executeStatement,
  });

  @override
  final SqlDialect dialect;

  @override
  final SqlStatement statement;

  final Future<SqlResult> Function(SqlStatement statement) executeStatement;

  @override
  Future<SqlResult> execute({Object? parameters}) {
    final compiled = switch (parameters) {
      null => statement,
      final Object value => SqlStatement(statement.sql, parameters: value),
    };

    return executeStatement(compiled);
  }

  @override
  Future<void> close() async {}
}
