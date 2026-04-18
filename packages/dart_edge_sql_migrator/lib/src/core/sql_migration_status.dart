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

  /// Whether every known migration is already applied.
  bool get isUpToDate => pending.isEmpty;
}
