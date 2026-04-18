import '../../core/sql_dialect.dart';
import '../../core/sql_executor.dart';
import '../../core/sql_result.dart';
import '../../core/sql_statement.dart';
import '../shared/native_sql_pool_delegate.dart';

/// PostgreSQL-backed [SqlPool] implementation.
final class PostgresPool implements SqlPool {
  PostgresPool._({
    required this.connectionString,
    required NativeSqlPoolDelegate delegate,
  }) : _delegate = delegate;

  /// Opens a PostgreSQL pool from a libpq-style connection string.
  factory PostgresPool.withUrl(String connectionString) {
    return PostgresPool._(
      connectionString: connectionString,
      delegate: NativeSqlPoolDelegate.openPostgres(connectionString),
    );
  }

  /// Connection string used to open the native PostgreSQL pool.
  final String connectionString;
  final NativeSqlPoolDelegate _delegate;

  /// Native `dart_edge_sql` handle for this database.
  int get nativeHandle => _delegate.nativeHandle;

  @override
  SqlDialect get dialect => _delegate.dialect;

  @override
  Future<SqlResult> execute(SqlStatement statement) {
    return _delegate.execute(statement);
  }

  @override
  Future<T> withSession<T>(Future<T> Function(SqlSession session) action) {
    return _delegate.withSession(action);
  }

  @override
  Future<T> withTransaction<T>(
    Future<T> Function(SqlTransaction transaction) action,
  ) {
    return _delegate.withTransaction(action);
  }

  @override
  Future<void> close() => _delegate.close();
}
