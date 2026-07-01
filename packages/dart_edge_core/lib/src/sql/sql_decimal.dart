/// Lossless SQL decimal value represented as database decimal text.
final class SqlDecimal {
  /// Creates a decimal from database decimal text.
  SqlDecimal(String value) : value = _validateDecimal(value);

  /// Creates a decimal from a Dart number.
  factory SqlDecimal.fromNum(num value) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'value',
        'SQL decimal values must be finite numbers.',
      );
    }
    return SqlDecimal(value.toString());
  }

  /// Converts a decoded JSON value into a decimal.
  factory SqlDecimal.fromJson(Object? value) {
    return switch (value) {
      final SqlDecimal value => value,
      final String value => SqlDecimal(value),
      final num value => SqlDecimal.fromNum(value),
      final Object? value => throw FormatException(
        'Invalid SQL decimal JSON value.',
        value,
      ),
    };
  }

  /// Database decimal text.
  final String value;

  /// Encodes this decimal as JSON.
  String toJson() => value;

  /// Encodes this decimal as PostgreSQL decimal text.
  String toPostgresText() => value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return other is SqlDecimal && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final _decimalPattern = RegExp(
  r'^[+-]?(?:(?:[0-9]+(?:\.[0-9]*)?)|(?:\.[0-9]+))(?:[eE][+-]?[0-9]+)?$',
);

String _validateDecimal(String value) {
  final trimmed = value.trim();
  if (!_decimalPattern.hasMatch(trimmed)) {
    throw FormatException('Invalid SQL decimal value.', value);
  }
  return trimmed;
}
