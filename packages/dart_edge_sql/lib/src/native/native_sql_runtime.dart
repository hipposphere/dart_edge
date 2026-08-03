import 'dart_edge_sql_native.dart';

/// Process-level lifecycle operations for the native SQL runtime.
abstract final class NativeSqlRuntime {
  /// Closes every native transaction and pool registered in this process.
  ///
  /// This is intended for embedders that replace their Dart isolate without
  /// running ordinary disposal callbacks, such as Flutter hot restart. Do not
  /// call it while another live isolate is expected to keep using SQL pools.
  static Future<void> closeAllPools() async {
    DartEdgeSqlNative.closeAllPools();
  }
}
