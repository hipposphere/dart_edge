import 'managed_postgres_endpoint.dart';

/// PostgreSQL endpoint exposed by a PGlite-backed database.
///
/// Implementations are expected to keep the PGlite server alive until
/// [close] is called. `PostgresPool.pglite` takes ownership of the endpoint
/// and closes it after the SQL pool has been closed.
abstract interface class PgliteEndpoint implements ManagedPostgresEndpoint {}
