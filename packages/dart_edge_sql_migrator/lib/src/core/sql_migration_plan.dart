import 'package:dart_edge_sql/dart_edge_sql.dart';

/// Dialect-aware SQL statements for one migration direction.
final class SqlMigrationPlan {
  const SqlMigrationPlan({
    this.shared = const <SqlStatement>[],
    this.byDialect = const <SqlDialect, List<SqlStatement>>{},
  });

  const SqlMigrationPlan.empty()
    : shared = const <SqlStatement>[],
      byDialect = const <SqlDialect, List<SqlStatement>>{};

  /// Statements executed for every supported dialect.
  final List<SqlStatement> shared;

  /// Additional statements applied only for a specific dialect.
  final Map<SqlDialect, List<SqlStatement>> byDialect;

  /// Creates a plan from shared statements only.
  factory SqlMigrationPlan.statements(Iterable<SqlStatement> statements) {
    return SqlMigrationPlan(
      shared: List<SqlStatement>.unmodifiable(statements),
    );
  }

  /// Creates a plan from shared raw SQL strings only.
  factory SqlMigrationPlan.sql(Iterable<String> statements) {
    return SqlMigrationPlan.statements([
      for (final statement in statements) sql(statement),
    ]);
  }

  /// Whether this plan contains no statements at all.
  bool get isEmpty =>
      shared.isEmpty &&
      byDialect.values.every((statements) => statements.isEmpty);

  /// Resolves the statements that should run for [dialect].
  List<SqlStatement> forDialect(SqlDialect dialect) {
    return List<SqlStatement>.unmodifiable([...shared, ...?byDialect[dialect]]);
  }
}
