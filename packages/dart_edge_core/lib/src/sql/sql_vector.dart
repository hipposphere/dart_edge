/// PostgreSQL pgvector value represented as a finite list of doubles.
final class SqlVector {
  /// Creates a vector from numeric values.
  SqlVector(Iterable<num> values)
    : values = List<double>.unmodifiable(
        values.map((value) {
          final doubleValue = value.toDouble();
          if (!doubleValue.isFinite) {
            throw ArgumentError.value(
              value,
              'values',
              'SQL vector values must be finite numbers.',
            );
          }
          return doubleValue;
        }),
      );

  /// Parses pgvector text output, for example `[1,2,3]`.
  factory SqlVector.parse(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
      throw FormatException('Invalid SQL vector literal.', value);
    }
    final body = trimmed.substring(1, trimmed.length - 1).trim();
    if (body.isEmpty) {
      return SqlVector(const <double>[]);
    }
    return SqlVector(
      body.split(',').map((part) {
        final text = part.trim();
        final parsed = double.tryParse(text);
        if (parsed == null) {
          throw FormatException('Invalid SQL vector value.', text);
        }
        return parsed;
      }),
    );
  }

  /// Converts a decoded JSON value into a vector.
  factory SqlVector.fromJson(Object? value) {
    return switch (value) {
      final SqlVector value => value,
      final String value => SqlVector.parse(value),
      final Iterable<Object?> value => SqlVector(
        value.map((item) {
          if (item case final num number) {
            return number;
          }
          throw FormatException('Invalid SQL vector JSON value.', item);
        }),
      ),
      final Object? value => throw FormatException(
        'Invalid SQL vector JSON value.',
        value,
      ),
    };
  }

  /// Vector elements.
  final List<double> values;

  /// Encodes this vector as a JSON list.
  List<double> toJson() => List<double>.unmodifiable(values);

  /// Encodes this vector as a pgvector text literal.
  String toPostgresText() => '[${values.map(_formatDouble).join(',')}]';

  @override
  String toString() => toPostgresText();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SqlVector || other.values.length != values.length) {
      return false;
    }
    for (var index = 0; index < values.length; index += 1) {
      if (values[index] != other.values[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);
}

String _formatDouble(double value) {
  if (value == value.truncateToDouble()) {
    return value.toStringAsFixed(1);
  }
  return value.toString();
}
