/// Typed SQL execution and query-building library for Dart Edge.
///
/// Import this library to work with [SqlPool] implementations, table/column
/// descriptors, `executor.builder` query entrypoints, and raw [SqlStatement]
/// values.
library dart_edge_sql;

export 'src/core/sql_dialect.dart';
export 'src/core/sql_executor.dart';
export 'src/core/sql_query_builder.dart';
export 'src/core/sql_result.dart';
export 'src/core/sql_row.dart';
export 'src/core/sql_schema.dart';
export 'src/core/sql_statement.dart';
export 'src/core/sql_value.dart';
export 'src/drivers/postgres/pglite_endpoint.dart';
export 'src/drivers/postgres/postgres_pool.dart';
export 'src/drivers/sqlite/sqlite_database.dart';
