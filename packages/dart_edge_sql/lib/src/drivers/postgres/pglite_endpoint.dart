/// PostgreSQL endpoint exposed by a PGlite-backed database.
///
/// Implementations are expected to keep the PGlite server alive until
/// [close] is called. `PostgresPool.pglite` takes ownership of the endpoint
/// and closes it after the SQL pool has been closed.
abstract interface class PgliteEndpoint {
  /// PostgreSQL wire-protocol connection string for the running PGlite server.
  String get connectionString;

  /// Stops the backing PGlite server and releases native resources.
  Future<void> close();
}
