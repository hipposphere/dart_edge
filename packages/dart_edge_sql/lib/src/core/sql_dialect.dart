/// SQL dialect understood by a driver or compiled statement.
enum SqlDialect {
  postgres(displayName: 'PostgreSQL'),
  sqlite(displayName: 'SQLite');

  const SqlDialect({required this.displayName});

  /// Human-readable dialect name.
  final String displayName;
}
