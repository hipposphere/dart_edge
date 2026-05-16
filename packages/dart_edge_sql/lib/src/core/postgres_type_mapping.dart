/// Shared PostgreSQL type-name helpers used by SQL query compilation and
/// schema code generation.
abstract final class PostgresTypeMapping {
  /// Returns the canonical parameter cast for a PostgreSQL type name.
  ///
  /// Type aliases that PostgreSQL accepts in DDL are normalized to the catalog
  /// names used for explicit parameter casts.
  static String? parameterCastFor(String? databaseType) {
    final type = databaseType?.trim();
    if (type == null || type.isEmpty) {
      return null;
    }

    final normalized = normalizeTypeName(type);
    return switch (normalized) {
      'bool' => normalized,
      'int2' || 'int4' || 'int8' => normalized,
      'uuid' ||
      'date' ||
      'time' ||
      'timetz' ||
      'timestamp' ||
      'timestamptz' ||
      'float4' ||
      'float8' ||
      'numeric' ||
      'decimal' ||
      'money' ||
      'json' ||
      'jsonb' ||
      'bytea' => normalized,
      _ when isUserDefinedType(normalized) => quoteTypeName(type),
      _ => null,
    };
  }

  /// Whether a PostgreSQL type should receive JSON text parameters.
  static bool usesJsonTextParameter(String? databaseType) {
    final type = databaseType?.trim();
    if (type == null || type.isEmpty) {
      return false;
    }
    return switch (normalizeTypeName(type)) {
      'json' || 'jsonb' => true,
      _ => false,
    };
  }

  /// Normalizes common PostgreSQL type aliases to catalog-style type names.
  static String normalizeTypeName(String databaseType) {
    final normalized = databaseType.trim().toLowerCase();
    return switch (normalized) {
      'smallint' => 'int2',
      'int' || 'integer' || 'serial' || 'serial4' => 'int4',
      'bigint' || 'bigserial' || 'serial8' => 'int8',
      'boolean' => 'bool',
      _ => normalized,
    };
  }

  /// Whether a normalized PostgreSQL type name should be treated as user-owned.
  static bool isUserDefinedType(String normalizedType) {
    if (normalizedType.startsWith('_')) {
      return false;
    }
    return !builtInTypeNames.contains(normalizedType);
  }

  /// Quotes a schema-qualified PostgreSQL type name.
  static String quoteTypeName(String databaseType) {
    return databaseType
        .split('.')
        .map((part) => '"${part.replaceAll('"', '""')}"')
        .join('.');
  }

  /// PostgreSQL built-in type names recognized by the typed SQL layer.
  static const builtInTypeNames = {
    'bool',
    'int2',
    'int4',
    'int8',
    'uuid',
    'date',
    'time',
    'timetz',
    'timestamp',
    'timestamptz',
    'float4',
    'float8',
    'numeric',
    'decimal',
    'money',
    'text',
    'varchar',
    'bpchar',
    'citext',
    'json',
    'jsonb',
    'bytea',
  };
}
