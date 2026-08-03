import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'native/dart_edge_sql_pglite_native.dart';
import 'pglite_extension.dart';

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

  /// Closes every PGlite endpoint still registered in this process.
  ///
  /// This is intended for embedded runtimes such as Flutter debug builds,
  /// where hot restart replaces the Dart isolate without first disposing its
  /// native resources. Do not call it while another live isolate is expected
  /// to keep using a PGlite endpoint.
  static Future<void> closeAll() async {
    await NativeSqlRuntime.closeAllPools();
    DartEdgeSqlPgliteNative.closeAll();
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
