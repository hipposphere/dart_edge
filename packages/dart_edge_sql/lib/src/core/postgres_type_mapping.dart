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
    if (arrayParameterCastFor(normalized) case final cast?) {
      return cast;
    }
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

  /// Returns the canonical parameter cast for a PostgreSQL array type name.
  static String? arrayParameterCastFor(String normalizedType) {
    if (normalizedType.endsWith('[]')) {
      final elementType = normalizedType.substring(
        0,
        normalizedType.length - 2,
      );
      if (elementType.isEmpty) {
        return null;
      }
      return '${_arrayElementCastFor(elementType)}[]';
    }
    if (!normalizedType.startsWith('_') || normalizedType.length == 1) {
      return null;
    }
    return '${_arrayElementCastFor(normalizedType.substring(1))}[]';
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

  /// Whether a PostgreSQL type should receive array-literal text parameters.
  static bool usesArrayTextParameter(String? databaseType) {
    final type = databaseType?.trim();
    if (type == null || type.isEmpty) {
      return false;
    }
    return arrayParameterCastFor(normalizeTypeName(type)) != null;
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

  static String _arrayElementCastFor(String normalizedElementType) {
    final elementType = normalizeTypeName(normalizedElementType);
    return isUserDefinedType(elementType)
        ? quoteTypeName(elementType)
        : elementType;
  }
}
