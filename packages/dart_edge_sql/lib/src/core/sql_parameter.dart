import 'dart:convert';

import 'postgres_type_mapping.dart';
import 'sql_decimal.dart';
import 'sql_dialect.dart';
import 'sql_value.dart';
import 'sql_vector.dart';

/// A SQL parameter with an explicit database type.
///
/// This is useful for raw SQL expressions where the database cannot infer the
/// desired parameter type from a generated [SqlColumn].
final class SqlParameter<T> {
  /// Creates a PostgreSQL typed parameter.
  const SqlParameter.postgres(this.value, this.postgresType);

  /// Runtime value passed to the database.
  final T value;

  /// PostgreSQL type name used as an explicit parameter cast.
  final String postgresType;

  /// Encodes [value] for [dialect].
  Object? encode(SqlDialect dialect) {
    final parameterValue = _unwrapSqlParameterValue(value);
    return switch (dialect) {
      SqlDialect.postgres => _encodePostgresParameterValue(
        parameterValue,
        postgresType,
      ),
      SqlDialect.sqlite => parameterValue,
    };
  }

  /// Explicit parameter cast for [dialect], if any.
  String? cast(SqlDialect dialect) {
    return switch (dialect) {
      SqlDialect.postgres => _postgresParameterCastFor(postgresType),
      SqlDialect.sqlite => null,
    };
  }
}

/// Convenient constructors for explicitly typed SQL parameters.
abstract final class SqlParam {
  /// Creates a parameter cast to an arbitrary PostgreSQL [type].
  static SqlParameter<T> postgres<T>(T value, String type) {
    return SqlParameter<T>.postgres(value, type);
  }

  /// Creates a PostgreSQL `bool` parameter.
  static SqlParameter<T> bool<T>(T value) => postgres(value, 'bool');

  /// Creates a PostgreSQL `int2` parameter.
  static SqlParameter<T> int2<T>(T value) => postgres(value, 'int2');

  /// Creates a PostgreSQL `int4` parameter.
  static SqlParameter<T> int4<T>(T value) => postgres(value, 'int4');

  /// Creates a PostgreSQL `int8` parameter.
  static SqlParameter<T> int8<T>(T value) => postgres(value, 'int8');

  /// Creates a PostgreSQL `float4` parameter.
  static SqlParameter<T> float4<T>(T value) => postgres(value, 'float4');

  /// Creates a PostgreSQL `float8` parameter.
  static SqlParameter<T> float8<T>(T value) => postgres(value, 'float8');

  /// Creates a PostgreSQL `numeric` parameter.
  static SqlParameter<T> numeric<T>(T value) => postgres(value, 'numeric');

  /// Creates a PostgreSQL `text` parameter.
  static SqlParameter<T> text<T>(T value) => postgres(value, 'text');

  /// Creates a PostgreSQL `uuid` parameter.
  static SqlParameter<T> uuid<T>(T value) => postgres(value, 'uuid');

  /// Creates a PostgreSQL `date` parameter.
  static SqlParameter<T> date<T>(T value) => postgres(value, 'date');

  /// Creates a PostgreSQL `time` parameter.
  static SqlParameter<T> time<T>(T value) => postgres(value, 'time');

  /// Creates a PostgreSQL `timestamp` parameter.
  static SqlParameter<T> timestamp<T>(T value) => postgres(value, 'timestamp');

  /// Creates a PostgreSQL `timestamptz` parameter.
  static SqlParameter<T> timestamptz<T>(T value) {
    return postgres(value, 'timestamptz');
  }

  /// Creates a PostgreSQL `json` parameter.
  static SqlParameter<T> json<T>(T value) => postgres(value, 'json');

  /// Creates a PostgreSQL `jsonb` parameter.
  static SqlParameter<T> jsonb<T>(T value) => postgres(value, 'jsonb');

  /// Creates a PostgreSQL `bytea` parameter.
  static SqlParameter<T> bytea<T>(T value) => postgres(value, 'bytea');

  /// Creates a PostgreSQL array parameter.
  static SqlParameter<T> array<T>(T value, String elementType) {
    return postgres(value, '$elementType[]');
  }

  /// Creates a PostgreSQL `vector` parameter.
  static SqlParameter<T> vector<T>(T value, {int? dimensions}) {
    return postgres(
      value,
      dimensions == null ? 'vector' : 'vector($dimensions)',
    );
  }
}

Object? _unwrapSqlParameterValue(Object? value) {
  return switch (value) {
    final SqlValue<dynamic> value when value.isPresent => value.value,
    final SqlValue<dynamic> value => throw ArgumentError.value(
      value,
      'value',
      'Absent SQL values cannot be used as query parameters.',
    ),
    _ => value,
  };
}

Object? _encodePostgresParameterValue(Object? value, String postgresType) {
  if (PostgresTypeMapping.usesArrayTextParameter(postgresType)) {
    return _encodePostgresArrayTextParameter(value);
  }
  if (PostgresTypeMapping.usesDecimalTextParameter(postgresType)) {
    return _encodePostgresDecimalTextParameter(value);
  }
  if (PostgresTypeMapping.usesVectorTextParameter(postgresType)) {
    return _encodePostgresVectorTextParameter(value);
  }
  if (PostgresTypeMapping.usesJsonTextParameter(postgresType)) {
    return _encodeJsonTextParameter(value);
  }
  return value;
}

String? _postgresParameterCastFor(String postgresType) {
  final type = postgresType.trim();
  if (type.isEmpty) {
    return null;
  }
  final normalized = PostgresTypeMapping.normalizeTypeName(type);
  if (PostgresTypeMapping.parameterCastFor(normalized) case final cast?) {
    return cast;
  }
  if (PostgresTypeMapping.builtInTypeNames.contains(normalized)) {
    return normalized;
  }
  final modifierIndex = normalized.indexOf('(');
  if (modifierIndex > 0 &&
      normalized.endsWith(')') &&
      PostgresTypeMapping.builtInTypeNames.contains(
        normalized.substring(0, modifierIndex),
      )) {
    return normalized;
  }
  return PostgresTypeMapping.quoteTypeName(type);
}

Object? _encodeJsonTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    _ => jsonEncode(_normalizeJsonValue(value)),
  };
}

Object? _normalizeJsonValue(Object? value) {
  return switch (value) {
    null || String() || bool() || num() => value,
    final Map<Object?, Object?> value => <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _normalizeJsonValue(entry.value),
    },
    final Iterable<Object?> value => [
      for (final item in value) _normalizeJsonValue(item),
    ],
    final Object value => throw ArgumentError.value(
      value,
      'value',
      'Unsupported JSON parameter value.',
    ),
  };
}

Object? _encodePostgresArrayTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    final Iterable<Object?> value =>
      '{${value.map(_postgresArrayElement).join(',')}}',
    _ => throw ArgumentError.value(
      value,
      'value',
      'PostgreSQL array parameters must be an Iterable, String, or null.',
    ),
  };
}

String _postgresArrayElement(Object? value) {
  if (value == null) {
    return 'NULL';
  }
  final text = switch (value) {
    final DateTime value => value.toUtc().toIso8601String(),
    final String value => value,
    final bool value => value.toString(),
    final num value => value.toString(),
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported PostgreSQL array parameter element.',
    ),
  };
  return '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

Object? _encodePostgresVectorTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    final SqlVector value => value.toPostgresText(),
    final Iterable<num> value => SqlVector(value).toPostgresText(),
    _ => throw ArgumentError.value(
      value,
      'value',
      'PostgreSQL vector parameters must be a SqlVector, Iterable<num>, String, or null.',
    ),
  };
}

Object? _encodePostgresDecimalTextParameter(Object? value) {
  return switch (value) {
    null || String() => value,
    final SqlDecimal value => value.toPostgresText(),
    final num value => SqlDecimal.fromNum(value).toPostgresText(),
    _ => throw ArgumentError.value(
      value,
      'value',
      'PostgreSQL decimal parameters must be a SqlDecimal, num, String, or null.',
    ),
  };
}
