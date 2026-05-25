import 'applied_sql_migration.dart';
import 'sql_migration.dart';

/// Current migration state for one database.
final class SqlMigrationStatus {
  const SqlMigrationStatus({
    required this.available,
    required this.applied,
    required this.pending,
  });

  /// All migrations known to the migrator in canonical order.
  final List<SqlMigration> available;

  /// Applied migrations loaded from the metadata table.
  final List<AppliedSqlMigration> applied;

  /// Migrations not yet applied.
  final List<SqlMigration> pending;

  /// Whether this database has at least one recorded Dart Edge migration.
  bool get hasAppliedMigrations => applied.isNotEmpty;

  /// Whether this database has known migrations that are not yet recorded.
  bool get hasPendingMigrations => pending.isNotEmpty;

  /// Whether every known migration is already applied.
  bool get isUpToDate => pending.isEmpty;

  /// Whether this status can be used for a one-time baseline handoff.
  ///
  /// This only means Dart Edge has no recorded migration metadata yet. Callers
  /// should still decide whether the physical database schema is an existing
  /// managed schema that should be baselined instead of migrated from scratch.
  bool get canBaseline => applied.isEmpty && available.isNotEmpty;
}
