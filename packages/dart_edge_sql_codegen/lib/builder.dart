import 'package:build/build.dart';

import 'src/builder/dart_edge_sql_builder.dart';

/// Creates the build_runner builder for checked-in SQL schema snapshots.
Builder dartEdgeSqlBuilder(BuilderOptions options) {
  return DartEdgeSqlBuilder(options);
}
