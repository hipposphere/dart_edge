import 'sql_migration_plan.dart';

/// One ordered schema migration.
final class SqlMigration {
  const SqlMigration({
    required this.version,
    required this.name,
    required this.up,
    this.down = const SqlMigrationPlan.empty(),
  });

  /// Stable version identifier used to order and record this migration.
  final String version;

  /// Human-readable name for the migration.
  final String name;

  /// Statements executed when the migration is applied.
  final SqlMigrationPlan up;

  /// Statements executed when the migration is rolled back.
  final SqlMigrationPlan down;
}
