/// Describes one generated SQL key extension type.
///
/// Generated SQL schema libraries expose these entries through a
/// `sqlKeyManifest` constant so tooling can discover stable key value objects
/// without parsing generated Dart source.
final class SqlKeyManifestEntry {
  const SqlKeyManifestEntry({
    required this.dartType,
    required this.baseDartType,
    required this.schema,
    required this.table,
    required this.column,
    this.nullable = false,
    this.external = false,
  });

  /// Generated Dart extension type name.
  final String dartType;

  /// Primitive Dart type wrapped by [dartType].
  final String baseDartType;

  /// SQL schema or namespace that owns the key.
  final String schema;

  /// SQL table that owns the key.
  final String table;

  /// SQL column that owns the key.
  final String column;

  /// Whether the key column is nullable.
  final bool nullable;

  /// Whether this key was configured externally instead of generated from an
  /// included table.
  final bool external;
}
