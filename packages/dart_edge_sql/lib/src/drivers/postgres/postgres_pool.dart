import 'dart:async';

import '../../core/sql_dialect.dart';
import '../../core/sql_executor.dart';
import '../../core/sql_result.dart';
import '../../core/sql_statement.dart';
import '../shared/native_sql_pool_delegate.dart';
import 'pglite_endpoint.dart';

/// PostgreSQL-backed [SqlPool] implementation.
final class PostgresPool implements SqlPool {
  PostgresPool._({
    required this.connectionString,
    required this._delegate,
    this._closeEndpoint,
  });

  /// Opens a PostgreSQL pool from a libpq-style connection string.
  factory PostgresPool.withUrl(
    String connectionString, {
    int maxSessions = 10,
  }) {
    return PostgresPool._(
      connectionString: connectionString,
      delegate: NativeSqlPoolDelegate.openPostgres(
        connectionString,
        maxSessions: maxSessions,
      ),
    );
  }

  /// Opens a single-session PostgreSQL pool backed by a PGlite server.
  ///
  /// This constructor takes ownership of [endpoint]. Closing the pool also
  /// closes the endpoint.
  factory PostgresPool.pglite(PgliteEndpoint endpoint) {
    final connectionString = endpoint.connectionString;
    try {
      return PostgresPool._(
        connectionString: connectionString,
        delegate: NativeSqlPoolDelegate.openPostgres(
          connectionString,
          maxSessions: 1,
        ),
        closeEndpoint: endpoint.close,
      );
    } catch (_) {
      unawaited(endpoint.close().catchError((_) {}));
      rethrow;
    }
  }

  /// Connection string used to open the native PostgreSQL pool.
  final String connectionString;
  final NativeSqlPoolDelegate _delegate;
  final Future<void> Function()? _closeEndpoint;
  var _closed = false;

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
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;

    try {
      await _delegate.close();
    } finally {
      await _closeEndpoint?.call();
    }
  }
}
