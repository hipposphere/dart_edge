import 'postgres_type_mapping.dart';

/// Native binder type retained for a PostgreSQL `NULL` parameter.
///
/// This is an internal wire value. PostgreSQL prepared statements cache their
/// parameter types, so a null must be bound with the same native type as a
/// later non-null value for the same statement.
enum NativeSqlValueKind { integer, double, boolean, string, bytes, dateTime }

/// A SQL `NULL` carrying the type expected by the native PostgreSQL binder.
final class NativeSqlNull {
  const NativeSqlNull(this.kind);

  final NativeSqlValueKind kind;

  @override
  bool operator ==(Object other) {
    return other is NativeSqlNull && other.kind == kind;
  }

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'NativeSqlNull(${kind.name})';
}

/// Returns a typed native null for [postgresType].
NativeSqlNull postgresTypedNull(String postgresType) {
  final normalized = PostgresTypeMapping.normalizeTypeName(postgresType);
  final kind = switch (normalized) {
    'bool' => NativeSqlValueKind.boolean,
    'int2' || 'int4' || 'int8' => NativeSqlValueKind.integer,
    'float4' || 'float8' => NativeSqlValueKind.double,
    'bytea' => NativeSqlValueKind.bytes,
    'date' || 'timestamp' || 'timestamptz' => NativeSqlValueKind.dateTime,
    _ => NativeSqlValueKind.string,
  };
  return NativeSqlNull(kind);
}
