/// Native SQL integration hooks for Dart Edge packages.
///
/// Most application code should import `dart_edge_sql.dart` instead. This
/// sublibrary exists for sibling native-backed packages that need to share a SQL
/// pool handle with the SQL native asset without importing private `src` files.
library dart_edge_sql_native;

export 'src/native/dart_edge_sql_native.dart';
