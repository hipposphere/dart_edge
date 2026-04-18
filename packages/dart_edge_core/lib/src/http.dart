/// Declares one documented error response for a route.
final class ErrorResponse {
  const ErrorResponse({required this.status, this.code});

  /// The HTTP status code returned for the error.
  final int status;

  /// Optional stable application-level error code.
  final String? code;

  /// Convenience helper for a `401 Unauthorized` response.
  static ErrorResponse unauthorized({String? code}) {
    return ErrorResponse(status: 401, code: code);
  }

  /// Convenience helper for a `404 Not Found` response.
  static ErrorResponse notFound({String? code}) {
    return ErrorResponse(status: 404, code: code);
  }

  /// Convenience helper for a `409 Conflict` response.
  static ErrorResponse conflict({String? code}) {
    return ErrorResponse(status: 409, code: code);
  }
}

/// Supported HTTP methods for [RouteContract]s.
enum HttpMethod { get, post, put, patch, delete, head, options }

/// Contract for values that know how to serialize themselves as JSON-friendly
/// Dart objects.
abstract interface class JsonEncodable {
  /// Converts this value into a JSON-friendly representation.
  Object? toJson();
}

/// Stable reference to a JSON Schema definition.
final class JsonSchemaRef<T> {
  const JsonSchemaRef(this.id);

  /// Stable schema identifier.
  final String id;

  /// Creates a schema ref using `T.toString()` as its identifier.
  static JsonSchemaRef<T> of<T>() => JsonSchemaRef<T>(T.toString());
}

/// Binds a [JsonSchemaRef] to its concrete JSON Schema object.
final class JsonSchemaDefinition {
  const JsonSchemaDefinition({required this.ref, required this.schema});

  /// Stable schema reference used by route contracts.
  final JsonSchemaRef<Object?> ref;

  /// Raw JSON Schema object.
  final Map<String, Object?> schema;

  /// Convenience alias for `ref.id`.
  String get id => ref.id;
}

/// Collection of JSON Schema definitions installed on an app.
final class JsonSchemaRegistry {
  const JsonSchemaRegistry({required this.definitions});

  /// All schema definitions known to the registry.
  final List<JsonSchemaDefinition> definitions;

  /// Looks up a schema definition by its identifier.
  JsonSchemaDefinition? definitionFor(String id) {
    for (final definition in definitions) {
      if (definition.id == id) {
        return definition;
      }
    }
    return null;
  }

  /// Returns the schema registry as a map keyed by schema id.
  Map<String, Map<String, Object?>> asMap() =>
      Map<String, Map<String, Object?>>.fromEntries(
        definitions.map(
          (definition) => MapEntry(definition.id, definition.schema),
        ),
      );
}

/// One raw HTTP header attached to a [RawResponse].
final class HttpHeader {
  const HttpHeader(this.name, this.value);

  /// Header name.
  final String name;

  /// Header value.
  final String value;
}

/// Fully specified HTTP response returned directly from a route handler.
final class RawResponse {
  const RawResponse({
    required this.status,
    required this.contentType,
    this.body = '',
    this.headers = const <HttpHeader>[],
    this.isEncodedBody = false,
  });

  /// HTTP status code.
  final int status;

  /// Full response content type.
  final String contentType;

  /// Response body before encoding.
  final Object? body;

  /// Extra response headers.
  final List<HttpHeader> headers;

  /// Whether [body] is already encoded and should be forwarded as-is.
  final bool isEncodedBody;

  /// Creates a JSON response whose body will be encoded by the runtime.
  factory RawResponse.json({
    required int status,
    Object? body,
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    return RawResponse(
      status: status,
      contentType: 'application/json; charset=utf-8',
      body: body,
      headers: headers,
    );
  }

  /// Creates a plain-text response.
  factory RawResponse.text({
    required int status,
    String body = '',
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    return RawResponse(
      status: status,
      contentType: 'text/plain; charset=utf-8',
      body: body,
      headers: headers,
    );
  }

  /// Creates a response whose body is already encoded for [contentType].
  factory RawResponse.encoded({
    required int status,
    required String contentType,
    String body = '',
    List<HttpHeader> headers = const <HttpHeader>[],
  }) {
    return RawResponse(
      status: status,
      contentType: contentType,
      body: body,
      headers: headers,
      isEncodedBody: true,
    );
  }
}

/// Declares the request body expected by a [RouteContract].
final class RequestBody {
  const RequestBody._({required this.contentType, this.ref});

  /// Expected request content type.
  final String contentType;

  /// Optional schema reference used to validate or document the body.
  final JsonSchemaRef<Object?>? ref;

  /// Declares a JSON request body backed by [ref].
  static RequestBody json<T>({required JsonSchemaRef<T> ref}) {
    return RequestBody._(
      contentType: 'application/json; charset=utf-8',
      ref: ref,
    );
  }

  /// Declares an untyped JSON request body.
  static RequestBody jsonValue() {
    return const RequestBody._(contentType: 'application/json; charset=utf-8');
  }

  /// Declares a plain-text request body.
  static RequestBody text() {
    return const RequestBody._(contentType: 'text/plain; charset=utf-8');
  }
}

/// Declares the default response encoding for a successful route result.
final class ResponseSpec {
  const ResponseSpec._({
    required this.status,
    required this.contentType,
    this.ref,
  });

  /// HTTP status code emitted for the response.
  final int status;

  /// Response content type.
  final String contentType;

  /// Optional schema reference used for documentation or validation.
  final JsonSchemaRef<Object?>? ref;

  /// Creates a JSON response specification.
  static ResponseSpec json<T>({int status = 200, JsonSchemaRef<T>? ref}) {
    return ResponseSpec._(
      status: status,
      contentType: 'application/json; charset=utf-8',
      ref: ref,
    );
  }

  /// Creates a plain-text response specification.
  static ResponseSpec text({int status = 200}) {
    return ResponseSpec._(
      status: status,
      contentType: 'text/plain; charset=utf-8',
    );
  }

  /// Creates an HTML response specification.
  static ResponseSpec html({int status = 200}) {
    return ResponseSpec._(
      status: status,
      contentType: 'text/html; charset=utf-8',
    );
  }
}

/// Groups the success and documented error responses for a route.
final class ResponseSet {
  const ResponseSet({
    required this.success,
    this.errors = const <ErrorResponse>[],
  });

  /// The primary success response returned by the route.
  final ResponseSpec success;

  /// Additional documented non-success responses.
  final List<ErrorResponse> errors;
}

/// Full HTTP contract for a [JsonRouteDefinition].
final class RouteContract {
  const RouteContract({
    required this.method,
    required this.path,
    required this.operationId,
    this.summary,
    this.tags = const <String>[],
    this.deprecated = false,
    this.params,
    this.query,
    this.headers,
    this.body,
    required this.responses,
  });

  /// HTTP method accepted by the route.
  final HttpMethod method;

  /// Route path pattern, for example `/users/<id>`.
  final String path;

  /// Stable identifier used in generated output and manifests.
  final String operationId;

  /// Optional short summary for documentation.
  final String? summary;

  /// Tags attached to the route in generated documentation.
  final List<String> tags;

  /// Whether the route should be marked as deprecated.
  final bool deprecated;

  /// Schema reference for decoded path parameters.
  final JsonSchemaRef<Object?>? params;

  /// Schema reference for decoded query parameters.
  final JsonSchemaRef<Object?>? query;

  /// Schema reference for decoded request headers.
  final JsonSchemaRef<Object?>? headers;

  /// Request body contract, if the route accepts a body.
  final RequestBody? body;

  /// Documented success and error responses.
  final ResponseSet responses;

  @override
  String toString() {
    final parts = <String>[
      '${_httpMethodLabel(method)} $path',
      'operationId: $operationId',
      if (body case final body?)
        'body: ${_contentLabel(body.contentType, schemaId: body.ref?.id)}',
      'success: ${responses.success.status} ${_contentLabel(responses.success.contentType, schemaId: responses.success.ref?.id)}',
      if (responses.errors.isNotEmpty)
        'errors: [${responses.errors.map(_errorLabel).join(', ')}]',
      if (tags.isNotEmpty) 'tags: $tags',
      if (deprecated) 'deprecated: true',
    ];
    return 'RouteContract(${parts.join(', ')})';
  }
}

String _httpMethodLabel(HttpMethod method) => method.name.toUpperCase();

String _contentLabel(String contentType, {required String? schemaId}) {
  if (schemaId case final schemaId?) {
    return '$contentType<$schemaId>';
  }
  return contentType;
}

String _errorLabel(ErrorResponse error) {
  if (error.code case final code?) {
    return '${error.status} $code';
  }
  return '${error.status}';
}
