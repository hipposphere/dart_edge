import 'dart:async';

import '../core/sql_dialect.dart';
import '../core/sql_executor.dart';
import '../core/sql_result.dart';
import '../core/sql_statement.dart';
import '../drivers/shared/compiled_sql_statement.dart';

/// Receives SQL trace events emitted by [TracingSqlPool].
typedef SqlTraceSink = FutureOr<void> Function(SqlTraceEvent event);

/// SQL operation that produced a trace event.
enum SqlTraceOperation {
  /// A statement was executed immediately.
  execute,

  /// A statement was prepared for later execution.
  prepare,

  /// A prepared statement was executed.
  preparedExecute,
}

/// Executor scope that produced a trace event.
enum SqlTraceSource {
  /// The operation ran directly on a pool.
  pool,

  /// The operation ran on a borrowed session.
  session,

  /// The operation ran inside a transaction.
  transaction,

  /// The operation ran through a prepared statement.
  preparedStatement,
}

/// Trace data for a SQL operation.
final class SqlTraceEvent {
  const SqlTraceEvent({
    required this.source,
    required this.operation,
    required this.dialect,
    required this.statement,
    required this.compiledStatement,
    required this.duration,
    this.result,
    this.error,
    this.stackTrace,
  });

  /// Executor scope that produced this event.
  final SqlTraceSource source;

  /// SQL operation that produced this event.
  final SqlTraceOperation operation;

  /// Dialect used to compile and execute the statement.
  final SqlDialect dialect;

  /// Original statement supplied by application code.
  final SqlStatement statement;

  /// Statement after named parameters and SQL values have been normalized.
  ///
  /// This is the SQL shape sent to the underlying driver.
  final SqlStatement compiledStatement;

  /// Time spent in the underlying SQL operation.
  final Duration duration;

  /// Result returned by the SQL operation, when it completed successfully.
  final SqlResult? result;

  /// Error thrown by the SQL operation, when it failed.
  final Object? error;

  /// Stack trace captured with [error].
  final StackTrace? stackTrace;

  /// Whether the SQL operation completed successfully.
  bool get succeeded => error == null;

  /// Number of rows returned by [result].
  int get returnedRows => result?.rows.length ?? 0;

  /// Number of rows affected by [result], when reported by the driver.
  int get affectedRows => result?.affectedRows ?? 0;
}

/// [SqlPool] wrapper that emits trace events for SQL execution.
///
/// The emitted event includes both the original statement and the compiled
/// statement sent to the driver, elapsed execution time, result metadata and
/// rows, or the thrown error.
final class TracingSqlPool implements SqlPool {
  const TracingSqlPool(
    this.delegate, {
    required this.onTrace,
    this.propagateTraceErrors = false,
  });

  /// Pool that performs the actual SQL work.
  final SqlPool delegate;

  /// Callback invoked after each traced SQL operation.
  final SqlTraceSink onTrace;

  /// Whether exceptions thrown by [onTrace] should fail the SQL operation.
  final bool propagateTraceErrors;

  @override
  SqlDialect get dialect => delegate.dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    return _traceExecute(
      source: SqlTraceSource.pool,
      operation: SqlTraceOperation.execute,
      statement: statement,
      execute: () => delegate.execute(statement),
    );
  }

  @override
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action) {
    return delegate.withSession(
      (session) => action(
        _TracingSqlSession(
          delegate: session,
          source: SqlTraceSource.session,
          onTrace: onTrace,
          propagateTraceErrors: propagateTraceErrors,
        ),
      ),
    );
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) {
    return delegate.withTransaction(
      (transaction) => action(
        _TracingSqlTransaction(
          delegate: transaction,
          onTrace: onTrace,
          propagateTraceErrors: propagateTraceErrors,
        ),
      ),
    );
  }

  @override
  Future<void> close() => delegate.close();

  Future<SqlResult> _traceExecute({
    required SqlTraceSource source,
    required SqlTraceOperation operation,
    required SqlStatement statement,
    required Future<SqlResult> Function() execute,
  }) {
    return _traceSqlResult(
      dialect: dialect,
      source: source,
      operation: operation,
      statement: statement,
      execute: execute,
      onTrace: onTrace,
      propagateTraceErrors: propagateTraceErrors,
    );
  }
}

final class _TracingSqlSession implements SqlSession {
  const _TracingSqlSession({
    required this.delegate,
    required this.source,
    required this.onTrace,
    required this.propagateTraceErrors,
  });

  final SqlSession delegate;
  final SqlTraceSource source;
  final SqlTraceSink onTrace;
  final bool propagateTraceErrors;

  @override
  SqlDialect get dialect => delegate.dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    return _traceSqlResult(
      dialect: dialect,
      source: source,
      operation: SqlTraceOperation.execute,
      statement: statement,
      execute: () => delegate.execute(statement),
      onTrace: onTrace,
      propagateTraceErrors: propagateTraceErrors,
    );
  }

  @override
  Future<PreparedSqlStatement> prepare(SqlStatement statement) async {
    final stopwatch = Stopwatch()..start();

    PreparedSqlStatement? prepared;
    Object? operationError;
    StackTrace? operationStackTrace;
    try {
      prepared = await delegate.prepare(statement);
    } catch (error, stackTrace) {
      operationError = error;
      operationStackTrace = stackTrace;
    }
    stopwatch.stop();

    final traceError = await _emitTraceForOperation(
      dialect: dialect,
      source: source,
      operation: SqlTraceOperation.prepare,
      statement: statement,
      duration: stopwatch.elapsed,
      error: operationError,
      stackTrace: operationStackTrace,
      onTrace: onTrace,
      propagateTraceErrors: propagateTraceErrors,
    );

    if (operationError != null) {
      Error.throwWithStackTrace(operationError, operationStackTrace!);
    }
    if (traceError case (final error, final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    return _TracingPreparedSqlStatement(
      delegate: prepared!,
      source: SqlTraceSource.preparedStatement,
      onTrace: onTrace,
      propagateTraceErrors: propagateTraceErrors,
    );
  }
}

final class _TracingSqlTransaction extends _TracingSqlSession
    implements SqlTransaction {
  const _TracingSqlTransaction({
    required SqlTransaction delegate,
    required super.onTrace,
    required super.propagateTraceErrors,
  }) : super(delegate: delegate, source: SqlTraceSource.transaction);
}

final class _TracingPreparedSqlStatement implements PreparedSqlStatement {
  const _TracingPreparedSqlStatement({
    required this.delegate,
    required this.source,
    required this.onTrace,
    required this.propagateTraceErrors,
  });

  final PreparedSqlStatement delegate;
  final SqlTraceSource source;
  final SqlTraceSink onTrace;
  final bool propagateTraceErrors;

  @override
  SqlDialect get dialect => delegate.dialect;

  @override
  SqlStatement get statement => delegate.statement;

  @override
  Future<SqlResult> execute({Object? parameters}) {
    final effectiveStatement = switch (parameters) {
      null => statement,
      final Object value => SqlStatement(statement.sql, parameters: value),
    };

    return _traceSqlResult(
      dialect: dialect,
      source: source,
      operation: SqlTraceOperation.preparedExecute,
      statement: effectiveStatement,
      execute: () => delegate.execute(parameters: parameters),
      onTrace: onTrace,
      propagateTraceErrors: propagateTraceErrors,
    );
  }

  @override
  Future<void> close() => delegate.close();
}

Future<SqlResult> _traceSqlResult({
  required SqlDialect dialect,
  required SqlTraceSource source,
  required SqlTraceOperation operation,
  required SqlStatement statement,
  required Future<SqlResult> Function() execute,
  required SqlTraceSink onTrace,
  required bool propagateTraceErrors,
}) async {
  final stopwatch = Stopwatch()..start();

  SqlResult? result;
  Object? operationError;
  StackTrace? operationStackTrace;
  try {
    result = await execute();
  } catch (error, stackTrace) {
    operationError = error;
    operationStackTrace = stackTrace;
  }
  stopwatch.stop();

  final traceError = await _emitTraceForOperation(
    dialect: dialect,
    source: source,
    operation: operation,
    statement: statement,
    duration: stopwatch.elapsed,
    result: result,
    error: operationError,
    stackTrace: operationStackTrace,
    onTrace: onTrace,
    propagateTraceErrors: propagateTraceErrors,
  );

  if (operationError != null) {
    Error.throwWithStackTrace(operationError, operationStackTrace!);
  }
  if (traceError case (final error, final stackTrace)) {
    Error.throwWithStackTrace(error, stackTrace);
  }

  return result!;
}

Future<(Object, StackTrace)?> _emitTraceForOperation({
  required SqlDialect dialect,
  required SqlTraceSource source,
  required SqlTraceOperation operation,
  required SqlStatement statement,
  required Duration duration,
  SqlResult? result,
  Object? error,
  StackTrace? stackTrace,
  required SqlTraceSink onTrace,
  required bool propagateTraceErrors,
}) async {
  final compiledStatement = _compileTraceStatement(dialect, statement);
  return _emitTrace(
    SqlTraceEvent(
      source: source,
      operation: operation,
      dialect: dialect,
      statement: statement,
      compiledStatement: compiledStatement,
      duration: duration,
      result: result,
      error: error,
      stackTrace: stackTrace,
    ),
    onTrace: onTrace,
    propagateTraceErrors: propagateTraceErrors,
  );
}

SqlStatement _compileTraceStatement(
  SqlDialect dialect,
  SqlStatement statement,
) {
  try {
    return compileSqlStatement(dialect, statement);
  } catch (_) {
    return statement;
  }
}

Future<(Object, StackTrace)?> _emitTrace(
  SqlTraceEvent event, {
  required SqlTraceSink onTrace,
  required bool propagateTraceErrors,
}) async {
  if (propagateTraceErrors) {
    try {
      await onTrace(event);
    } catch (error, stackTrace) {
      return (error, stackTrace);
    }
    return null;
  }

  try {
    await onTrace(event);
  } catch (_) {}
  return null;
}
