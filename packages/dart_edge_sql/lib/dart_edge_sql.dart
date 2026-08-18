/// Typed SQL execution and query-building library for Dart Edge.
///
/// Import this library to work with [SqlPool] implementations, table/column
/// descriptors, `executor.typed` / `executor.raw` query roots, and raw
/// [SqlStatement] values.
library;

export 'src/core/postgres_type_mapping.dart';
export 'src/core/sql_decimal.dart';
export 'src/core/sql_dialect.dart';
export 'src/core/sql_executor.dart';
export 'src/core/sql_parameter.dart';
export 'src/core/sql_query_builder.dart';
export 'src/core/sql_result.dart';
export 'src/core/sql_row.dart';
export 'src/core/sql_schema.dart' hide SqlRawTable;
export 'src/core/sql_script.dart';
export 'src/core/sql_statement.dart';
export 'src/core/sql_value.dart';
export 'src/core/sql_vector.dart';
export 'src/drivers/postgres/managed_postgres_endpoint.dart';
export 'src/drivers/postgres/pglite_endpoint.dart';
export 'src/drivers/postgres/postgres_pool.dart';
export 'src/drivers/postgres/postgres_text_search.dart';
export 'src/drivers/sqlite/sqlite_database.dart';
export 'src/native/native_sql_runtime.dart';
export 'src/tracing/tracing_sql_pool.dart';
