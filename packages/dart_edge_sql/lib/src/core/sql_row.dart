import 'dart:collection';

/// Immutable row returned from SQL execution.
final class SqlRow {
  SqlRow(Map<String, Object?> values)
    : _values = UnmodifiableMapView<String, Object?>(Map.of(values));

  final UnmodifiableMapView<String, Object?> _values;

  /// Reads a column by name without casting.
  Object? operator [](String columnName) => _values[columnName];

  /// Whether the row contains [columnName].
  bool containsKey(String columnName) => _values.containsKey(columnName);

  /// Reads a non-null column value as [T].
  T read<T>(String columnName) {
    if (!_values.containsKey(columnName)) {
      throw StateError('Missing SQL column "$columnName".');
    }

    final value = _values[columnName];
    if (value == null) {
      if (null is T) {
        return value as T;
      }
      throw StateError('SQL column "$columnName" was null.');
    }
    return value as T;
  }

  /// Reads a nullable column value as [T].
  T? readNullable<T>(String columnName) => _values[columnName] as T?;

  /// Returns the row as an immutable map.
  Map<String, Object?> asMap() => _values;

  @override
  String toString() => _values.toString();
}
