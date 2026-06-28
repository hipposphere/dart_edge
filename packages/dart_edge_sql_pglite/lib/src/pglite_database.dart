import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'native/dart_edge_sql_pglite_native.dart';

/// Bundled PGlite extension to install before exposing the database.
final class PgliteExtension {
  /// Creates an extension by its SQL extension name.
  const PgliteExtension(this.sqlName);

  /// pgvector, exposed in SQL as `vector`.
  static const vector = PgliteExtension('vector');

  /// PostgreSQL trigram matching extension.
  static const pgTrgm = PgliteExtension('pg_trgm');

  /// PostgreSQL case-insensitive text extension.
  static const citext = PgliteExtension('citext');

  /// PostgreSQL hstore extension.
  static const hstore = PgliteExtension('hstore');

  /// PostgreSQL tree-like label path extension.
  static const ltree = PgliteExtension('ltree');

  /// SQL extension name passed to PGlite, for example `vector`.
  final String sqlName;

  @override
  String toString() => sqlName;
}

/// Embedded PGlite database exposed as a PostgreSQL endpoint.
final class PgliteDatabase implements PgliteEndpoint {
  PgliteDatabase._({
    required this._handle,
    required this.connectionString,
    required this.storagePath,
  });

  /// Starts a temporary PGlite database.
  factory PgliteDatabase.temporary({
    Iterable<PgliteExtension> extensions = const [],
  }) {
    final handle = DartEdgeSqlPgliteNative.openTemporary(
      extensions: extensions.map((extension) => extension.sqlName),
    );
    return PgliteDatabase._(
      handle: handle,
      connectionString: DartEdgeSqlPgliteNative.connectionString(handle),
      storagePath: null,
    );
  }

  /// Starts a persistent PGlite database rooted at [path].
  factory PgliteDatabase.open(
    String path, {
    Iterable<PgliteExtension> extensions = const [],
  }) {
    final handle = DartEdgeSqlPgliteNative.openPersistent(
      path,
      extensions: extensions.map((extension) => extension.sqlName),
    );
    return PgliteDatabase._(
      handle: handle,
      connectionString: DartEdgeSqlPgliteNative.connectionString(handle),
      storagePath: path,
    );
  }

  /// Native `dart_edge_sql_pglite` handle for this endpoint.
  int get nativeHandle => _handle;

  @override
  final String connectionString;

  /// Filesystem path for persistent databases, or `null` for temporary ones.
  final String? storagePath;

  final int _handle;
  var _closed = false;

  /// Creates a `dart_edge_sql` PostgreSQL pool backed by this PGlite database.
  ///
  /// The returned pool owns this endpoint. Closing the pool closes this
  /// database as well.
  PostgresPool asPostgresPool() => PostgresPool.pglite(this);

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    DartEdgeSqlPgliteNative.close(_handle);
  }
}
