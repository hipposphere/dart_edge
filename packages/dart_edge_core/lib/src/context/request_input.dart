/// Holds decoded request input values for a route handler.
final class RequestInput {
  const RequestInput({
    this.paramsValue,
    this.queryValue,
    this.headerValue,
    this.bodyValue,
  });

  /// Decoded path parameters.
  final Object? paramsValue;

  /// Decoded query object.
  final Object? queryValue;

  /// Decoded header object.
  final Object? headerValue;

  /// Decoded request body.
  final Object? bodyValue;

  /// Reads the path parameters as [T].
  T params<T>() => _read<T>(paramsValue, 'params');

  /// Reads the query payload as [T].
  T query<T>() => _read<T>(queryValue, 'query');

  /// Reads the header payload as [T].
  T headers<T>() => _read<T>(headerValue, 'headers');

  /// Reads the request body as [T].
  T body<T>() => _read<T>(bodyValue, 'body');

  static T _read<T>(Object? value, String label) {
    if (value is T) {
      return value;
    }

    throw StateError('No $label value of type $T is available.');
  }
}
