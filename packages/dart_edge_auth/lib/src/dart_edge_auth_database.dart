import 'package:dart_edge_sql/dart_edge_sql.dart';

/// Native database configuration used by `dart_edge_auth`.
///
/// Shared databases reuse one live `dart_edge_sql` native handle across SQL and
/// auth operations. Dedicated database configs open a separate native backend
/// owned by `dart_edge_auth`.
sealed class DartEdgeAuthDatabase {
  const DartEdgeAuthDatabase();

  /// Use Better Auth's in-memory database adapter.
  const factory DartEdgeAuthDatabase.memory() = MemoryDartEdgeAuthDatabase;

  /// Use Better Auth's native PostgreSQL adapter.
  const factory DartEdgeAuthDatabase.postgres({
    required String connectionString,
  }) = PostgresDartEdgeAuthDatabase;

  /// Use Better Auth's native SQLite adapter.
  const factory DartEdgeAuthDatabase.sqlite({
    required String path,
    bool inMemory,
    bool manageMigrations,
  }) = SqliteDartEdgeAuthDatabase;

  /// Shares an existing native `dart_edge_sql` database with Better Auth.
  factory DartEdgeAuthDatabase.fromDatabase(
    SqlPool database, {
    bool manageMigrations = true,
  }) {
    return SharedDartEdgeAuthDatabase(
      database: database,
      manageMigrations: manageMigrations,
    );
  }

  /// Derives a PostgreSQL auth database config from an existing native pool.
  factory DartEdgeAuthDatabase.fromPostgresPool(
    PostgresPool pool, {
    bool manageMigrations = true,
  }) {
    return DartEdgeAuthDatabase.fromDatabase(
      pool,
      manageMigrations: manageMigrations,
    );
  }

  /// Derives a SQLite auth database config from an existing native pool.
  ///
  /// This shares the existing native `dart_edge_sql` handle, including
  /// `:memory:` SQLite databases.
  factory DartEdgeAuthDatabase.fromSqliteDatabase(
    SqliteDatabase database, {
    bool manageMigrations = true,
  }) {
    return DartEdgeAuthDatabase.fromDatabase(
      database,
      manageMigrations: manageMigrations,
    );
  }

  /// Whether `dart_edge_auth` should manage the Better Auth schema itself.
  bool get manageMigrations;

  Map<String, Object?> toJson();
}

final class MemoryDartEdgeAuthDatabase extends DartEdgeAuthDatabase {
  const MemoryDartEdgeAuthDatabase();

  @override
  bool get manageMigrations => false;

  @override
  Map<String, Object?> toJson() => const {'kind': 'memory'};
}

final class PostgresDartEdgeAuthDatabase extends DartEdgeAuthDatabase {
  const PostgresDartEdgeAuthDatabase({required this.connectionString});

  final String connectionString;

  @override
  bool get manageMigrations => false;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'postgres',
    'connectionString': connectionString,
  };
}

final class SqliteDartEdgeAuthDatabase extends DartEdgeAuthDatabase {
  const SqliteDartEdgeAuthDatabase({
    required this.path,
    this.inMemory = false,
    this.manageMigrations = true,
  });

  final String path;
  final bool inMemory;
  @override
  final bool manageMigrations;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'sqlite',
    'path': path,
    'inMemory': inMemory,
    'manageMigrations': manageMigrations,
  };
}

final class SharedDartEdgeAuthDatabase extends DartEdgeAuthDatabase {
  SharedDartEdgeAuthDatabase({
    required this.database,
    this.manageMigrations = true,
  });

  final SqlPool database;
  @override
  final bool manageMigrations;

  SqlDialect get dialect => database.dialect;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'shared',
    'dialect': dialect.name,
    'manageMigrations': manageMigrations,
  };
}
