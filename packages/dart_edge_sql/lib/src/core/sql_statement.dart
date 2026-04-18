/// SQL statement plus its optional parameter payload.
final class SqlStatement {
  const SqlStatement(this.sql, {this.parameters});

  /// SQL text to execute.
  final String sql;

  /// Statement parameters.
  ///
  /// Supported values are `List<Object?>`, `Map<String, Object?>`, or `null`.
  final Object? parameters;

  /// Creates a statement that uses named parameters.
  static SqlStatement named(String sql, Map<String, Object?> parameters) =>
      SqlStatement(sql, parameters: parameters);

  /// Creates a statement that uses positional parameters.
  static SqlStatement positional(String sql, List<Object?> parameters) =>
      SqlStatement(sql, parameters: parameters);

  /// Returns the named parameter map when one was supplied.
  Map<String, Object?>? get namedParameters => switch (parameters) {
    final Map<String, Object?> value => value,
    _ => null,
  };

  /// Returns the positional parameter list when one was supplied.
  List<Object?> get positionalParameters => switch (parameters) {
    null => const <Object?>[],
    final List<Object?> value => value,
    final Map<String, Object?> _ => const <Object?>[],
    final Object value => throw ArgumentError.value(
      value,
      'parameters',
      'SQL parameters must be a List<Object?>, Map<String, Object?>, or null.',
    ),
  };

  /// Whether this statement uses named parameters.
  bool get usesNamedParameters => namedParameters != null;
}

/// Convenience helper for constructing a [SqlStatement].
SqlStatement sql(String text, {Object? parameters}) =>
    SqlStatement(text, parameters: parameters);
