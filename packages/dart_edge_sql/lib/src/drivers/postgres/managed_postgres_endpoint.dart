/// Lifecycle contract for a locally managed PostgreSQL-compatible server.
///
/// Implementations keep the backing server alive until [close] is called.
/// [PostgresPool.managed] takes ownership of the endpoint and closes it after
/// the SQL pool has closed.
abstract interface class ManagedPostgresEndpoint {
  /// PostgreSQL wire-protocol connection string for the running server.
  String get connectionString;

  /// Stops the backing server and releases its resources.
  Future<void> close();
}
