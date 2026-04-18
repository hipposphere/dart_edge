/// One migration row already recorded in the database metadata table.
final class AppliedSqlMigration {
  const AppliedSqlMigration({
    required this.version,
    required this.name,
    required this.appliedAt,
  });

  /// Stable migration version identifier.
  final String version;

  /// Human-readable migration name recorded at apply time.
  final String name;

  /// Timestamp when the migration was recorded as applied.
  final DateTime appliedAt;
}
