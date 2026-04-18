import 'sql_dialect.dart';
import 'sql_result.dart';
import 'sql_statement.dart';

/// Minimal interface for executing SQL statements.
abstract interface class SqlExecutor {
  /// Dialect used by the executor.
  SqlDialect get dialect;

  /// Executes [statement] and returns its result.
  Future<SqlResult> execute(SqlStatement statement);
}

/// Executor that can also prepare statements.
abstract interface class SqlSession implements SqlExecutor {
  /// Prepares [statement] for repeated execution.
  Future<PreparedSqlStatement> prepare(SqlStatement statement);
}

/// Session that is currently running inside a transaction.
abstract interface class SqlTransaction implements SqlSession {}

/// Prepared statement returned from [SqlSession.prepare].
abstract interface class PreparedSqlStatement {
  /// Dialect used by the prepared statement.
  SqlDialect get dialect;

  /// Source statement used to create this prepared statement.
  SqlStatement get statement;

  /// Executes the prepared statement.
  ///
  /// When [parameters] is omitted, the original [statement.parameters] are
  /// reused.
  Future<SqlResult> execute({Object? parameters});

  /// Releases the prepared statement.
  Future<void> close();
}

/// Driver-level connection pool.
abstract interface class SqlPool implements SqlExecutor {
  /// Borrows a session from the pool for the duration of [action].
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action);

  /// Runs [action] inside a transaction.
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  );

  /// Closes the pool and releases its resources.
  Future<void> close();
}
