/// SQL migration manager for Dart Edge SQLite and PostgreSQL applications.
///
/// Import this library to define ordered migrations, inspect migration status,
/// and apply or roll back schema changes through the existing `dart_edge_sql`
/// driver surface.
library dart_edge_sql_migrator;

export 'src/core/applied_sql_migration.dart';
export 'src/core/dart_edge_sql_migrator.dart';
export 'src/core/sql_file_migration_source.dart';
export 'src/core/sql_migration.dart';
export 'src/core/sql_migration_file_sorting.dart';
export 'src/core/sql_migration_plan.dart';
export 'src/core/sql_migration_status.dart';
