import '../../core/sql_dialect.dart';
import '../../core/sql_executor.dart';
import '../../core/sql_result.dart';
import '../../core/sql_statement.dart';
import '../shared/native_sql_pool_delegate.dart';

/// SQLite-backed [SqlPool] implementation.
final class SqliteDatabase implements SqlPool {
  SqliteDatabase._({
    required this.path,
    required this.maxSessions,
    required this.isInMemory,
    required this._delegate,
  });

  /// Opens a SQLite database from [path].
  factory SqliteDatabase.open(String path, {int maxSessions = 1}) {
    if (maxSessions < 1) {
      throw ArgumentError.value(
        maxSessions,
        'maxSessions',
        'maxSessions must be at least 1.',
      );
    }

    return SqliteDatabase._(
      path: path,
      maxSessions: maxSessions,
      isInMemory: false,
      delegate: NativeSqlPoolDelegate.openSqlite(
        path,
        maxSessions: maxSessions,
      ),
    );
  }

  /// Opens an in-memory SQLite database.
  factory SqliteDatabase.inMemory({int maxSessions = 1}) {
    if (maxSessions < 1) {
      throw ArgumentError.value(
        maxSessions,
        'maxSessions',
        'maxSessions must be at least 1.',
      );
    }

    return SqliteDatabase._(
      path: ':memory:',
      maxSessions: maxSessions,
      isInMemory: true,
      delegate: NativeSqlPoolDelegate.openSqliteInMemory(
        maxSessions: maxSessions,
      ),
    );
  }

  /// Path used to open the SQLite database, or `:memory:` for an in-memory DB.
  final String path;

  /// Requested maximum number of native SQLite sessions.
  final int maxSessions;

  /// Whether this pool uses an in-memory SQLite database.
  final bool isInMemory;

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
