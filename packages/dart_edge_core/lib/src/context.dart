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

/// Telemetry hook associated with one request.
///
/// Route handlers can use this object to record domain events without taking a
/// direct dependency on the transport middleware implementation.
final class RequestTelemetry {
  const RequestTelemetry();

  /// Records an event for the current request.
  void addEvent(
    String event, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {}
}

/// Per-request context passed to a route handler.
///
/// It gives handlers access to app services, decoded input values, telemetry,
/// and request-scoped extensions populated by guards or surrounding code.
final class RequestContext<TServices> {
  RequestContext({
    required this.services,
    this.input = const RequestInput(),
    this.telemetry = const RequestTelemetry(),
  });

  /// Fresh services instance for the current request.
  final TServices services;

  /// Decoded request params, query, headers, and body.
  final RequestInput input;

  /// Telemetry hook associated with this request.
  final RequestTelemetry telemetry;
  final Map<Type, Object?> _extensions = <Type, Object?>{};

  /// Reads a required request-scoped extension of type [T].
  T require<T>() {
    final value = maybe<T>();
    if (value == null) {
      throw StateError('Missing request-scoped value for $T.');
    }
    return value;
  }

  /// Reads an optional request-scoped extension of type [T].
  T? maybe<T>() => _extensions[T] as T?;

  /// Stores a request-scoped extension by its runtime type.
  void put<T>(T value) {
    _extensions[T] = value;
  }
}
