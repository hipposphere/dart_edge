/// Database dialect supported by the SQL schema generator.
enum SqlCodegenDialect { postgres, sqlite }

/// Reusable configuration object for schema introspection and code generation.
final class SqlCodegenConfig {
  const SqlCodegenConfig({
    required this.dialect,
    required this.outputDirectory,
    this.connectionString,
    this.sqlitePath,
    this.schema,
    this.includeTables = const <String>{},
    this.excludeTables = const <String>{},
    this.databaseClassName = 'GeneratedDatabaseSchema',
  });

  /// Source database dialect.
  final SqlCodegenDialect dialect;

  /// Output directory for the generated structured Dart source tree.
  final String outputDirectory;

  /// PostgreSQL connection string when [dialect] is `postgres`.
  final String? connectionString;

  /// SQLite database path when [dialect] is `sqlite`.
  final String? sqlitePath;

  /// PostgreSQL schema to introspect.
  final String? schema;

  /// Optional allow-list of tables to include.
  final Set<String> includeTables;

  /// Optional block-list of tables to exclude.
  final Set<String> excludeTables;

  /// Root database class emitted into the generated entrypoint file.
  final String databaseClassName;
}
