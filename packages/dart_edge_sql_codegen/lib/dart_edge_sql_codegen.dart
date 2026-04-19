/// Schema introspection and code-generation helpers for `dart_edge_sql`.
///
/// Import this library to introspect a database schema and emit a structured
/// Dart source tree for schema descriptors, typed row models, and JSON Schema
/// metadata.
library dart_edge_sql_codegen;

export 'src/codegen/dart_schema_emitter.dart';
export 'src/codegen/sql_codegen_config.dart';
export 'src/introspection/introspected_database.dart';
export 'src/introspection/postgres_introspector.dart';
export 'src/introspection/sql_database_introspector.dart';
export 'src/introspection/sqlite_introspector.dart';
