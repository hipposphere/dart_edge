/// Database dialect supported by the SQL schema generator.
enum SqlCodegenDialect { postgres, sqlite }

/// JSON representation for PostgreSQL `int8`/`bigint` columns.
enum SqlInt8JsonEncoding { number, string }

/// Declares a generated value type for a primary key outside the generated
/// table set.
final class ExternalPrimaryKeySpec {
  const ExternalPrimaryKeySpec({
    required this.typeName,
    required this.baseDartType,
  });

  /// Generated extension type name, for example `AuthUserId`.
  final String typeName;

  /// Dart type used for the value stored inside the extension type.
  final String baseDartType;
}

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
    this.primaryKeyExtensionTypes = true,
    this.int8JsonEncoding = SqlInt8JsonEncoding.number,
    this.externalPrimaryKeys = const <String, ExternalPrimaryKeySpec>{},
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

  /// Whether generated models use extension types for single-column primary
  /// keys and matching single-column foreign keys.
  final bool primaryKeyExtensionTypes;

  /// JSON representation for PostgreSQL `int8`/`bigint` columns.
  final SqlInt8JsonEncoding int8JsonEncoding;

  /// External primary key specs keyed by `schema.table.column`.
  ///
  /// These let foreign keys reference excluded tables while still using a
  /// generated extension type such as `AuthUserId`.
  final Map<String, ExternalPrimaryKeySpec> externalPrimaryKeys;
}
